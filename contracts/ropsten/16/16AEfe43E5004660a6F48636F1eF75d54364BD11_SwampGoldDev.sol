// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

    import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
    import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";

    contract SwampGoldDev is Initializable, ContextUpgradeable,  OwnableUpgradeable, ERC20CappedUpgradeable {
        address public implementation;
        uint256 season;
        mapping(uint256 => mapping(uint256 => bool)) toadzSeasonClaimedByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) flyzSeasonClaimedByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) polzSeasonClaimedByTokenId;
    bool public paused;
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
    uint256[] private _claimedToadz;
    uint256[] private _claimedFlyz;
    uint256[] private _claimedPolz;

    function initialize() public initializer{
      __ERC20_init("Swamp Gold", "SGLD");
      __Ownable_init();
      ERC20CappedUpgradeable.__ERC20Capped_init_unchained(90000000 * (10**decimals()));
      init();
    }

    function init() internal {
        address toadziContractAddress = 0xE5524aAD7BEf1e1bF711C55d63D9Bf9C8e2a5C2C;
        address flyziContractAddress = 0x1Fd612bFBe4c47dC462C8A8F032d0dC9dA75185a;
        address polziContractAddress = 0x13f2954330B4A2AC0271C740f8e2f8879dbf772D;
        toadz.nftiContractAddress = toadziContractAddress;
        toadz.iContractAddress = IERC721EnumerableUpgradeable(toadziContractAddress);
        toadz.tokenAmount = 8500 * (10**decimals());
        toadz.tokenStartId = 1;
        toadz.tokenEndId = 7025;
        flyz.nftiContractAddress = flyziContractAddress;
        flyz.iContractAddress = IERC721EnumerableUpgradeable(flyziContractAddress);
        flyz.tokenAmount = 1500 * (10**decimals());
        flyz.tokenStartId = 1;
        flyz.tokenEndId = 7026;
        polz.nftiContractAddress = polziContractAddress;
        polz.iContractAddress = IERC721EnumerableUpgradeable(polziContractAddress);
        polz.tokenAmount = 1000 * (10**decimals());
        polz.tokenStartId = 1;
        polz.tokenEndId = 10000;
        season = 0;
        }

    function setPaused(bool _paused) public
        onlyOwner {
        paused = _paused;
    }

    function claimToadzById(uint256 tokenId) external {
        require(paused == false, "Contract Paused");
        require(
            _msgSender() == toadz.iContractAddress.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimToadz(tokenId, _msgSender());
    }

    function claimFlyzById(uint256 tokenId) external {
        require(paused == false, "Contract Paused");
        require(
            _msgSender() == flyz.iContractAddress.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimFlyz(tokenId, _msgSender());
    }

    function claimPolzById(uint256 tokenId) external {
        require(paused == false, "Contract Paused");
        require(
            _msgSender() == polz.iContractAddress.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimPolz(tokenId, _msgSender());
    }
    function claimAllToadz() external {
        uint256 tokenBalanceOwner = toadz.iContractAddress.balanceOf(_msgSender());
        require(paused == false, "Contract Paused");
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
        require(paused == false, "Contract Paused");
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
        require(paused == false, "Contract Paused");
        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimPolz(
                polz.iContractAddress.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }

    function _claimToadz(uint256 tokenId, address tokenOwner) internal {
        require(paused == false, "Contract Paused");
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
        _claimedToadz.push(tokenId);
    }

    function _claimFlyz(uint256 tokenId, address tokenOwner) internal {
        require(paused == false, "Contract Paused");
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
        _claimedFlyz.push(tokenId);
    }


    function _claimPolz(uint256 tokenId, address tokenOwner) internal {
        require(paused == false, "Contract Paused");
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
        _claimedPolz.push(tokenId);
    }

    function claimedToadz() public view returns (uint256[] memory) {
        return _claimedToadz;
    }
    
    function claimedFlyz() public view returns (uint256[] memory) {
        return _claimedFlyz;
    }
    
    function claimedPolz() public view returns (uint256[] memory) {
        return _claimedToadz;
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
    function DAOMint(uint256 amountDisplayValue) external onlyOwner {
        _mint(owner(), amountDisplayValue * (10**decimals()));
    }

}