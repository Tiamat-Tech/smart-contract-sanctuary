pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface SupportsERC721Depositable { 
    function addDeposit(uint256 tokenId) external;
}

contract Erc721Staking is Context, AccessControl, SupportsERC721Depositable {

    address private erc721Contract;
    uint64 private unlockPeriod;

    struct DepositState {
        uint256 tokenId; // changing it to uint32 should be enough 
        uint64 unlockPeriod;
        uint64 lockedUntil;
    }

    mapping(address => DepositState) private _deposit; // it is possible to deposit only one token per user

    event NftDeposit(address indexed from, uint256 indexed tokenId);
    event NftWithdrawalRequest(address indexed from, uint256 indexed tokenId, uint256 until);
    event NftWithdrawal(address indexed from, uint256 tokenId);

    constructor(address _erc721Contract) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        erc721Contract = _erc721Contract;
        unlockPeriod = 14 days; // this is decided unilaterally and is the same for everybody
    }

    function getTokenId(address depositer) external view returns (uint256) {
        DepositState storage ds = _deposit[depositer];
        return ds.tokenId;
    }

    function getUnlockPeriod(address depositer) external view returns (uint64) {
        DepositState storage ds = _deposit[depositer];
        return ds.unlockPeriod;
    }

    function getLockedUntil(address depositer) public view returns (uint64) {
        DepositState storage ds = _deposit[depositer];
        return ds.lockedUntil;
    }

    function getStandardUnlockPeriod() public view returns (uint64) {
        return unlockPeriod;
    }

    function getErc721Contract() public view returns (address) {
        return erc721Contract;
    }

    function setUnlockPeriod(uint64 period) external {
        hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
        require(period < 366 days);
        unlockPeriod = period;
    }

    function addDeposit(uint256 tokenId) override external {
        require(tokenId != 0);
        IERC721 nftInstance = IERC721(erc721Contract);
        DepositState storage ds = _deposit[_msgSender()];
        require(ds.tokenId == 0, "Erc721Staking: You already deposited one token"); // Mind, we do not have tokenId == 0 in Alice Land contract
        nftInstance.transferFrom(_msgSender(), address(this), tokenId);

        ds.tokenId = tokenId;
        ds.unlockPeriod = unlockPeriod;
        emit NftDeposit(_msgSender(), tokenId);
    }

    function requestWithdraw() external {
        DepositState storage ds = _deposit[_msgSender()];
        require(ds.tokenId > 0, "Erc721Staking: You did not deposit any token");
        require(ds.lockedUntil == 0, "You already requested to unlock it"); // second check should never verify
        ds.lockedUntil = uint64(block.timestamp + ds.unlockPeriod);

        emit NftWithdrawalRequest(_msgSender(), ds.tokenId, ds.lockedUntil);
    }

    function withdraw() external {
        DepositState storage ds = _deposit[_msgSender()];
        require(ds.tokenId > 0, "Erc721Staking: You did not deposit any token");
        require(uint64(block.timestamp) > ds.lockedUntil, "Erc721Staking: time of withdrawal did not come yet");

        IERC721 nftInstance = IERC721(erc721Contract);
        nftInstance.safeTransferFrom(address(this), _msgSender(), ds.tokenId);
        
        ds.lockedUntil = 0;
        ds.tokenId = 0;
        ds.unlockPeriod = 0;
        ds.tokenId = 0;

        emit NftWithdrawal(_msgSender(), ds.tokenId);
    }

}