//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import "../interfaces/IRedemption.sol";
import "../interfaces/IRhoToken.sol";

contract Redemption is IRedemption, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable, ERC721BurnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    uint256 public totalIssued;
    uint256 public override lockDuration;
    IRhoToken public override rhoToken;
    IERC20MetadataUpgradeable public override underlying;
    // mapping(uint256 => bool) public override locked;
    mapping(uint256 => Redeemable) public override redeemable;

    function initialize(uint256 lockDuration_, address rhoToken_, address underlying_) public initializer {
        __ERC721_init("rho Redemption Token", "rhoRdmpt");
        rhoToken = IRhoToken(rhoToken_);
        underlying = IERC20MetadataUpgradeable(underlying_);
        // _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setLockDuration(lockDuration_);
    }

    function setLockDuration(uint256 lockDuration_) external override {
        _setLockDuration(lockDuration_);
    }
    function _setLockDuration(uint256 lockDuration_) internal {
        lockDuration = lockDuration_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721EnumerableUpgradeable, ERC721PausableUpgradeable, ERC721Upgradeable) {
        ERC721EnumerableUpgradeable._beforeTokenTransfer(from, to, tokenId);
        ERC721PausableUpgradeable._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, ERC721Upgradeable) returns (bool) {
        return ERC721EnumerableUpgradeable.supportsInterface(interfaceId);
    }

    function redeemAll() external override nonReentrant {
        Redeemable[] memory r = _redeemableAssets();
        for (uint i = 0; i < r.length; i++) {
            if (r[i].amountInRho == 0) continue;
            uint256 tokenId = r[i].tokenId;
            burn(tokenId);
            rhoToken.burn(address(this), redeemable[tokenId].amountInRho);
            redeemable[tokenId].underlying.safeTransfer(
                ownerOf(tokenId),
                redeemable[tokenId].amountInRho * (10 ** redeemable[tokenId].underlying.decimals()) / (10 ** rhoToken.decimals())
            );
            delete redeemable[tokenId];
        }
    }
    function redeemableAssets() external view override returns(Redeemable[] memory){
        return _redeemableAssets();
    }
    function locked(uint256 tokenId) external view override returns(bool) {
        return _locked(tokenId);
    }
    function _locked(uint256 tokenId) internal view returns(bool) {
        return redeemable[tokenId].lockedUntil >= block.number;
    }
    function _redeemableAssets() internal view returns(Redeemable[] memory r){
        uint256 balance = balanceOf(_msgSender());
        r = new Redeemable[](balance);
        for (uint i = 0; i < balance; i++) {
            uint tokenId = tokenOfOwnerByIndex(_msgSender(), i);
            if(_locked(tokenId)) {
                r[i] = Redeemable(tokenId, 0, redeemable[tokenId].underlying, 0);
                continue;
            }
            r[i] = redeemable[tokenId];
        }
    }

    function mint(address owner, uint256 amountInRho) external override nonReentrant {
        rhoToken.transferFrom(owner, address(this), amountInRho);
        uint256 tokenId = ++totalIssued;
        Redeemable memory a = Redeemable(tokenId, amountInRho, underlying, uint96(block.number) + uint96(lockDuration));
        redeemable[tokenId] = a;
        _safeMint(owner, tokenId);
        emit RedemptionRequested(a);
    }
}