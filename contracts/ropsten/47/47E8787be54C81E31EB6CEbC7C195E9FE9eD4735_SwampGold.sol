// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";


contract SwampGold is Initializable, ContextUpgradeable, ERC20Upgradeable, OwnableUpgradeable {
    address public implementation;
    uint256 season;
    mapping(uint256 => mapping(uint256 => bool)) toadzSeasonClaimedByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) flyzSeasonClaimedByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) polzSeasonClaimedByTokenId;

    struct CyrptoContractInfo {
        address nftiContractAddress;
        IERC721EnumerableUpgradeable iContractAddress;
        uint256 tokenAmount;
        uint256 tokenStartId;
        uint256 tokenEndId;
    }
    CyrptoContractInfo toadz;
    CyrptoContractInfo flyz;
    CyrptoContractInfo polz;

    function initialize() initializer public {
      __ERC20_init("Swamp Gold", "SGLD");
      __Ownable_init();
      init();
    }

    function init() internal {

        address toadziContractAddress = 0xb00261DAD6a85AFE3b97579C689fb4a59867E304;
        address flyziContractAddress = 0x1Fd612bFBe4c47dC462C8A8F032d0dC9dA75185a;
        address polziContractAddress = 0x13f2954330B4A2AC0271C740f8e2f8879dbf772D;
        toadz.nftiContractAddress = toadziContractAddress;
        toadz.iContractAddress = IERC721EnumerableUpgradeable(toadziContractAddress);
        toadz.tokenAmount = 8500 * (10**decimals());
        toadz.tokenStartId = 1;
        toadz.tokenEndId = 8000;
        flyz.nftiContractAddress = flyziContractAddress;
        flyz.iContractAddress = IERC721EnumerableUpgradeable(flyziContractAddress);
        flyz.tokenAmount = 1500 * (10**decimals());
        flyz.tokenStartId = 1;
        flyz.tokenEndId = 8000;
        polz.nftiContractAddress = polziContractAddress;
        polz.iContractAddress = IERC721EnumerableUpgradeable(polziContractAddress);
        polz.tokenAmount = 1000 * (10**decimals());
        polz.tokenStartId = 1;
        polz.tokenEndId = 8000;
        season = 0;
    }

       function claimToadzById(uint256 tokenId) external {

        require(
            _msgSender() == toadz.iContractAddress.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimToadz(tokenId, _msgSender());
    }

    function claimFlyzById(uint256 tokenId) external {

        require(
            _msgSender() == flyz.iContractAddress.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimFlyz(tokenId, _msgSender());
    }

    function claimPolzById(uint256 tokenId) external {

        require(
            _msgSender() == polz.iContractAddress.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimPolz(tokenId, _msgSender());
    }
    function claimAllToadz() external {
        uint256 tokenBalanceOwner = toadz.iContractAddress.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimToadz(
                toadz.iContractAddress.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }
    function claimAllFlyz() external {
        uint256 tokenBalanceOwner = flyz.iContractAddress.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimFlyz(
                flyz.iContractAddress.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }
    function claimAllPolz() external {
        uint256 tokenBalanceOwner = polz.iContractAddress.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimPolz(
                polz.iContractAddress.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }

    function _claimToadz(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= toadz.tokenStartId && tokenId <= toadz.tokenEndId,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !toadzSeasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );

        toadzSeasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, toadz.tokenAmount);
    }

    function _claimFlyz(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= flyz.tokenStartId && tokenId <= flyz.tokenEndId,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !polzSeasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );

        polzSeasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, flyz.tokenAmount);
    }


    function _claimPolz(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= polz.tokenStartId && tokenId <= polz.tokenEndId,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !polzSeasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );

        polzSeasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, polz.tokenAmount);
    }

    function SetToadzGold(uint256 toadzGold)
        public
        onlyOwner
    {
        toadz.tokenAmount = toadzGold * (10**decimals());
    }
    
    function SetFlyzGold(uint256 flyzGold)
        public
        onlyOwner
    {
        flyz.tokenAmount = flyzGold * (10**decimals());
    }
    
    function SetPolzGold(uint256 polzGold)
        public
        onlyOwner
    {
        polz.tokenAmount = polzGold * (10**decimals());
    }

    function upgradeTo(address _newImplementation) external onlyOwner
    {
        require(implementation != _newImplementation, "Not Owner");
        _setImplementation(_newImplementation);
    }
    function _setImplementation(address _newImp) internal {
        implementation = _newImp;
    }
    function daoMint(uint256 amountDisplayValue) external {
        _mint(owner(), amountDisplayValue * (10**decimals()));
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

}