// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./IATrollCity.sol";
import "./RandomnessEnabledUpgradable.sol";

contract ATrollCity is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, RandomnessEnabledUpgradable, IATrollCity {

    using SafeMathUpgradeable for uint256;
    using StringsUpgradeable for uint256;
    using AddressUpgradeable for address;

    // Zero Address
    address constant ZERO_ADDRESS = address(0);

    uint256 constant roundZeroPrice = 0.1 ether;
    uint256 constant roundOnePrice = 0.15 ether;
    uint256 constant roundTwoPrice = 0.2 ether;
    uint256 constant roundThreePrice = 0.3 ether;

    uint256 constant roundZeroSupply = 250;
    uint256 constant roundOneSupply = 2000;
    uint256 constant roundTwoSupply = 2250;
    uint256 constant roundThreeSupply = 500;

    uint256 constant buyBackPoolPercentageShare = 7;
    uint256 constant lpPoolPercentageShare = 3;

    uint256 constant maxSupply = 5000;

    uint256 public round;
    bool public isSaleActive;

    address private buyBackPool;
    address private lpPool;
    string private _baseURIPrefix;
    uint256 private _liability;

    mapping(address => bool) public whitelist;
    mapping(uint256 => address) private _originalOwners;
    mapping(address => uint256) private _dividendAmount;

    function initialize(
        string memory _tokenName, 
        string memory _tokenSymbol, 
        string memory _uri,
        address _buyBackPool,
        address _lpPool
    ) initializer public {
        __ERC721_init(_tokenName, _tokenSymbol);
        __RandomnessEnabled_init();
        __Pausable_init();
        __Ownable_init();

        isSaleActive = true;
        _baseURIPrefix = _uri;
        buyBackPool = _buyBackPool;
        lpPool = _lpPool;
    }

    function mint() external payable override whenNotPaused {
        require(isSaleActive, "Sale must be active to mint NFT");
        require(totalSupply() < maxSupply, "Max supply exceeded");
        require(totalSupply() < getSupplyCapForRound(round), "Supply cap exceeded");
        if (totalSupply() < roundZeroSupply)
            require(whitelist[_msgSender()], "Not whitelisted");
        require(getNFTPriceForRound(round) <= msg.value, "Insufficient balance");

        uint256 tokenId = getRandomNFTTokenID();

        _safeMint(_msgSender(), tokenId);
        _originalOwners[tokenId] = msg.sender;
        transferReflection();
        emit NewNFT(tokenId);
    }

    function airDrop(address assigned, uint256 amount) external override onlyOwner whenNotPaused {
        require(isSaleActive, "Sale must be active to mint NFT");
        require(totalSupply() < maxSupply, "Max supply exceeded");
        require(totalSupply() < getSupplyCapForRound(round), "Supply cap exceeded");
        if (totalSupply() < roundZeroSupply)
            require(whitelist[assigned], "Not whitelisted");

        for (uint256 i = 0; i < amount; i++){
            uint256 tokenId = getRandomNFTTokenID();
            _safeMint(assigned, tokenId);
            _originalOwners[tokenId] = msg.sender;
            emit NewNFT(tokenId);
        }
    }

    function claimReward() external override nonReentrant {
        uint256 rewardAmount = _dividendAmount[msg.sender];
        require(rewardAmount > 0, "Caller has no reward amount");
        _liability = _liability.sub(rewardAmount);
        _dividendAmount[msg.sender] = 0;
        payable(msg.sender).transfer(rewardAmount);
    }

    function transferReflection() internal virtual nonReentrant {
        uint256 priceForCurrentRound = getNFTPriceForRound(round);
        uint256 dividend = (calculatePercentage(5, priceForCurrentRound)).div(totalSupply());
        for (uint256 i = 0; i < totalSupply(); i++){
            uint256 tokenIDOld = tokenByIndex(i);
            address addressTokenOld = ownerOf(tokenIDOld);
            uint256 oldDividend = _dividendAmount[addressTokenOld];
            _dividendAmount[addressTokenOld] = oldDividend.add(dividend);
            _liability = _liability.add(dividend);
        }
        uint256 buyBackPoolAmount = calculatePercentage(buyBackPoolPercentageShare, priceForCurrentRound);
        payable(buyBackPool).transfer(buyBackPoolAmount);
        uint256 lpPoolAmount = calculatePercentage(lpPoolPercentageShare, priceForCurrentRound);
        payable(lpPool).transfer(lpPoolAmount);
    }

    function getSupplyCapForRound(uint256 input) internal pure returns (uint256 supplyCapForRound){
        if(input == 0){
            return roundZeroSupply;
        }
        else if(input == 1){
            return roundOneSupply;
        }
        else if(input == 2){
            return roundTwoSupply;
        }
        else if(input == 3){
            return roundThreeSupply;
        }
    }

    function getNFTPriceForRound(uint256 input) internal pure returns (uint256 priceNFTForRound){
        if(input == 0){
            return roundZeroPrice;
        }
        else if(input == 1){
            return roundOnePrice;
        }
        else if(input == 2){
            return roundTwoPrice;
        }
        else if(input == 3){
            return roundThreePrice;
        }
    }

    function setSaleActive(bool isActive) external override onlyOwner {
        require(isSaleActive != isActive, "Sale status is already equal to supplied value");
        isSaleActive = isActive;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIPrefix;
    }

    function baseURI() external view override returns (string memory) {
        return _baseURI();
    }

    function setBaseURI(string memory newUri) external override onlyOwner whenNotPaused {
        require(
            keccak256(bytes(newUri)) != keccak256(bytes(_baseURIPrefix)),
            "New URI cannot be same as old URI"
        );
        _baseURIPrefix = newUri;
        emit SetBaseURI(newUri);
    }

    function setWhitelist(address[] calldata newAddresses) external override onlyOwner whenNotPaused {
        for (uint256 i = 0; i < newAddresses.length; i++){
            whitelist[newAddresses[i]] = true;
        }
        emit SetNewWhiteList();
    }

    function removeWhitelist(address[] calldata currentAddresses) external override onlyOwner whenNotPaused {
        for (uint256 i = 0; i < currentAddresses.length; i++){
            delete whitelist[currentAddresses[i]];
        }
        emit RemoveFromWhiteList();
    }

    function startNextRoundSale() external override onlyOwner whenNotPaused {
        require(round < 3, "Maximum Sale Round already set");
        round += 1;
    }

    function originalOwnerOf(uint256 tokenId) external view virtual override returns (address) {
        return _originalOwners[tokenId];
    }

    function checkAvailableReward() external override view returns (uint256) {
        return _dividendAmount[msg.sender];
    }

    function liability() external view onlyOwner returns (uint256) {
        return _liability;
    }

    function calculatePercentage(uint256 percentage, uint256 price) internal pure returns (uint256){
        return (price.mul(percentage)).div(100);
    }

    function setBuyBackPoolAddress (address _buyBackPoolAddress) external onlyOwner{
        buyBackPool = _buyBackPoolAddress;
    }

    function setLPPoolAddress (address _lpPoolAddress) external onlyOwner{
        lpPool = _lpPoolAddress;
    }

    function withdraw() external override onlyOwner nonReentrant{
        uint256 contractBalance = address(this).balance;
        require(contractBalance > _liability, "Contract only has liability amount");
        uint256 eligibleWithdrawAmount = contractBalance.sub(_liability);
        payable(owner()).transfer(eligibleWithdrawAmount);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual whenNotPaused override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}