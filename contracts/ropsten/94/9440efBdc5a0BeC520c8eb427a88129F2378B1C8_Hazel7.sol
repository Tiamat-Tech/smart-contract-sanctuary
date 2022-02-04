// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface LootInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface MLootInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Hazel7 is ERC721, IERC2981, ReentrancyGuard, Ownable{
	using Counters for Counters.Counter;

	// Project info
	uint256 public constant TOTAL_SUPPLY = 20000;
	uint256 public constant MINT_PRICE = 0.001 ether;

	// Royalty
	uint256 public royaltyPercentage;
	address public royaltyAddress;
	
	// Contrat's state
	bool public isSaleActive = false;
	bool public isPresaleActive = false;
	bool public isPublicSaleActive = false;
	bool private _isLootPublicSaleActive = false;
	bool private _isWhitelistSaleActive = true;
	bool private _isSpecialSetMinted = false;
	string private _baseTokenURI;

	// 3 different types of bag used to mint HyperLoot
	uint16 private constant _lootType = 0;
	uint16 private constant _mlootType = 1;
	uint16 private constant _gaType = 2;

	// Total 5 group = loot, whitelist, mloot, ga, special set
	// Supply for different groups
	uint16 private constant _supplyLoot = 7776;
	uint16 private constant _supplyGiveaway = 224;
	uint16 private constant _supplyWhitelist = 1000;
	uint16 private constant _supplyMLoot = 10593;
	uint16 private constant _supplyGA = 400;
	uint16 private constant _supplySpecialSet = 7;

	// Token count for different groups
	uint16 private _tokenIdStartMLoot = 8001;
	uint16 private _tokenIdStartGA = 19594;
	uint16 private _tokenIdStartSpecialSet = 19994;
	Counters.Counter private _countTokenLoot;
	Counters.Counter private _countTokenWhitelist;
	Counters.Counter private _countTokenMLoot;
	Counters.Counter private _countTokenGA;

	// Specific address claimable info
	mapping(address => bool) private _whitelist;
	mapping(address => uint256) private _giveawayList;

	// Claimed mloot and ga states
	mapping(uint256 => bool) private _claimedMLoot;
	mapping(uint256 => bool) private _claimedGA;

	// Creators address
	address creator1 = 0xF0a1A6788531EC973e372C531b4cECcF395378f3;
	address creator2 = 0x486817BD6fE09e90Af5a4A775034ae545ce7Fcea;
	address creator3 = 0x130F73eCF2d6DF8Da37b9811e7DBcFb6b71FED8a;

	// Loot Contract
	address private lootAddress = 0xD6dE102057378E4398baa2026401FE48b4c4d6BD;
	LootInterface lootContract = LootInterface(lootAddress);

	// More Loot Contract
	address private mlootAddress = 0x93a4EE4f24652E2793A4f4B16518F9D12f3CC333;
	MLootInterface mlootContract = MLootInterface(mlootAddress);

	// TokenType = [Loot, MLoot, GA, Giveaway]
	event HazelMinted(uint256 indexed id, uint256 indexed fromTokenType, uint256 indexed fromTokenId, uint8[4] traits);
	event HazelMultiMinted(uint256 indexed id, uint256 indexed fromTokenType, uint256 indexed fromTokenId, uint8 faceId, uint8 eyesId, uint8 backgroundId, uint8 leftHandId);

	constructor() ERC721("Hazel7", "HZL7") {}

	// ————————————————— //
	// ——— Modifiers ——— //
	// ————————————————— //

	modifier saleActive() {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		_;
	}

	modifier presaleActive() {
		require(isPresaleActive, "PRESALE_NOT_ACTIVE");
		_;
	}

	modifier publicSaleActive() {
		require(isPublicSaleActive, "PUBLIC_SALE_NOT_ACTIVE");
		_;
	}

	modifier ownLoot(uint256 lootId) {
		_checkLootOwner(lootId);
		_;
	}

	modifier ownMLoot(uint256 mlootId) {
		_checkMLootOwner(mlootId);
		_;
	}

	modifier isPaymentValid(uint256 amount) {
		require((MINT_PRICE * amount) <= msg.value, "WRONG_ETHER_VALUE");
		_;
	}

	modifier isTraitValid(uint8[4] calldata traits) {
		_checkFaceTrait(traits[0]);
		_checkEyesTrait(traits[1]);
		_checkBackgroundTrait(traits[2]);
		_checkLeftHandTrait(traits[3]);
		_;
	}

	modifier isMLootSupplyAvailable() {
		require(_countTokenMLoot.current() < (_supplyMLoot - _supplyWhitelist), "SOLD_OUT");
		_;
	}

	modifier isWhitelistSupplyAvailable() {
		require(_countTokenWhitelist.current() < _supplyWhitelist, "SOLD_OUT");
		require(_whitelist[msg.sender], "ADDRESS_NOT_WHITELISTED");
		_;
	}

	modifier isGiveawaySupplyAvailable(uint256 lootId) {
		require(lootId > 7777 && lootId < 8001, "TOKEN_ID_OUT_OF_RANGE");
		// Only allowed to mint specific loot id
		require(_giveawayList[msg.sender] == lootId, "ADDRESS_NOT_ELIGIBLE");
        _;
	}

	// —————————————————————————————————— //
	// ——— Public/Community Functions ——— //
	// —————————————————————————————————— //

	// Token ID 1 - 8000; 7836 & 7881 has been minted by dom
	function mintWithLoot(uint256 lootId, uint8[4] calldata traits) public payable
		nonReentrant
		presaleActive
		ownLoot(lootId)
		isPaymentValid(1)
		isTraitValid(traits) {
		_mintHazelEvent(msg.sender, lootId, _lootType, lootId, traits);
		_countTokenLoot.increment();
	}

    function mintWithLootCheck(uint256 lootId, uint8[4] calldata traits) public payable
		nonReentrant
		presaleActive
		ownLoot(lootId)
		isPaymentValid(1) {
        _checkEyesTrait(traits[0]);
        _checkFaceTrait(traits[1]);
        _checkBackgroundTrait(traits[2]);
        _checkLeftHandTrait(traits[3]);

		_mintHazelEvent(msg.sender, lootId, _lootType, lootId, traits);
		_countTokenLoot.increment();
	}

	// Token ID 8,001 - 18993
	function mintWithMLoot(uint256 mlootId, uint8[4] calldata traits) public payable
		nonReentrant 
		publicSaleActive
		isMLootSupplyAvailable
		ownMLoot(mlootId)
		isPaymentValid(1)
		isTraitValid(traits) {
		_mintHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), _mlootType, mlootId, traits);
		_claimMLoot(mlootId);
	}

	function multiMint(uint256[] calldata bagIds, uint16[] calldata bagType, uint8[] calldata faceIds, uint8[] calldata eyesIds, uint8[] calldata backgroundIds, uint8[] calldata leftHandIds) public payable
		nonReentrant
		presaleActive
		isPaymentValid(bagIds.length) {
            require(bagIds.length == bagType.length, "TRAITS_MISS_MATCH");
            require(bagIds.length == faceIds.length, "TRAITS_MISS_MATCH");
            require(bagIds.length == eyesIds.length, "TRAITS_MISS_MATCH");
            require(bagIds.length == backgroundIds.length, "TRAITS_MISS_MATCH");
            require(bagIds.length == leftHandIds.length, "TRAITS_MISS_MATCH");

            for (uint8 index = 0; index < bagIds.length; index++) {
                _checkEyesTrait(eyesIds[index]);
                _checkFaceTrait(faceIds[index]);
                _checkBackgroundTrait(backgroundIds[index]);
                _checkLeftHandTrait(leftHandIds[index]);

                uint bagId = bagIds[index];
                if (bagType[index] == _lootType) {
                    _checkLootOwner(bagId);
                    _mintMultiHazelEvent(msg.sender, bagId, _lootType, bagId, faceIds[index], eyesIds[index], backgroundIds[index], leftHandIds[index]);
                    _countTokenLoot.increment();
                } else if (bagType[index] == _mlootType) {
                    _checkMLootOwner(bagId);
                    _mintMultiHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), _mlootType, bagId, faceIds[index], eyesIds[index], backgroundIds[index], leftHandIds[index]);
                    _claimMLoot(bagId);
                }
            }
	}

	function _checkLootOwner(uint256 lootId) private view {
		require(lootId < 8001, "TOKEN_ID_OUT_OF_RANGE");
		require(lootContract.ownerOf(lootId) == msg.sender, "MUST_OWN_TOKEN_ID");
	}

	function _checkMLootOwner(uint256 mlootId) private view {
		require(mlootId > 8000, "TOKEN_ID_OUT_OF_RANGE");
		require(mlootContract.ownerOf(mlootId) == msg.sender, "MUST_OWN_TOKEN_ID");
		require(!_claimedMLoot[mlootId], "MLOOT_ALREADY_CLAIMED");
	}

	function _checkEyesTrait(uint8 eyesId) private pure {
		// 12 type of eyes
		require(eyesId >= 0 && eyesId < 12, "EYES_TRAIT_OUT_OF_RANGE");
	}

	function _checkFaceTrait(uint8 faceId) private pure {
		// 12 type of face
		require(faceId >= 0 && faceId < 12, "FACE_TRAIT_OUT_OF_RANGE");
	}

	function _checkBackgroundTrait(uint8 backgroundId) private pure {
		// 8 type of face
		require(backgroundId >= 0 && backgroundId < 8, "BACKGROUND_TRAIT_OUT_OF_RANGE");
	}

	function _checkLeftHandTrait(uint8 leftHandId) private pure {
		// 4 type of left hand
		require(leftHandId >= 0 && leftHandId < 4, "LEFT_HAND_TRAIT_OUT_OF_RANGE");
	}

	function _claimMLoot(uint256 mlootId) private {
		_countTokenMLoot.increment();
		_claimedMLoot[mlootId] = true;
	}

	function _mintHazelEvent(address _to, uint256 _tokenId, uint256 _tokenType, uint256 _fromTokenId, uint8[4] calldata traits) private {
		_mintHazel(_to, _tokenId);
		emit HazelMinted(_tokenId, _tokenType, _fromTokenId, traits);
	}

	function _mintMultiHazelEvent(address _to, uint256 _tokenId, uint256 _tokenType, uint256 _fromTokenId, uint8 faceIds, uint8 eyesIds, uint8 backgroundIds, uint8 leftHandIds) private {
		_mintHazel(_to, _tokenId);
		emit HazelMinted(_tokenId, _tokenType, _fromTokenId, [faceIds, eyesIds, backgroundIds, leftHandIds]);
	}

	function _mintHazel(address _to, uint256 _tokenId) private {
		_safeMint(_to, _tokenId);
	}

	function totalLootMinted() public view returns (uint256) {
		return _countTokenLoot.current();
	}

	function totalWhitelistMinted() public view returns (uint256) {
		return _countTokenWhitelist.current();
	}

	function totalMLootMinted() public view returns (uint256) {
		return _countTokenMLoot.current();
	}

	function totalGAMinted() public view returns (uint256) {
		return _countTokenGA.current();
	}
	
	function totalSupply() public view returns (uint256) {
		return _countTokenLoot.current() + _countTokenWhitelist.current() + _countTokenMLoot.current() + _countTokenGA.current();
	}

	function isLootClaimed(uint256 lootId) public view {
		require (!_exists(lootId), "LOOT_ALREADY_CLAIMED");
	}

	function isMLootClaimed(uint256 mlootId) public view {
		require(!_claimedMLoot[mlootId], "MLOOT_ALREADY_CLAIMED");
	}

	// ————————————————————————————— //
	// ——— Admin/Owner Functions ——— //
	// ————————————————————————————— //

	function setSale(bool saleState) external onlyOwner {
		isSaleActive = saleState;
	}

	function setPresale(bool saleState) external onlyOwner {
		isPresaleActive = saleState;
	}

	function setPublicsale(bool saleState) external onlyOwner {
		isPublicSaleActive = saleState;
	}

	function setWhitelist(address[] calldata addresses) external onlyOwner {
		for (uint256 i = 0; i < addresses.length; i++) {
			_whitelist[addresses[i]] = true;
		}
	}

	function setGiveaway(address[] calldata addresses, uint256[] calldata lootIds) external onlyOwner {
		for (uint256 i = 0; i < addresses.length; i++) {
			_giveawayList[addresses[i]] = lootIds[i];
		}
	}

	function setWhitelistSupplyPublic() external onlyOwner {
		_isWhitelistSaleActive = false;
	}

	function setLootSupplyPublic() external onlyOwner {
		_isLootPublicSaleActive = true;
	}

	function setBaseURI(string memory baseURI) public onlyOwner {
		_baseTokenURI = baseURI;
	}

	function _baseURI() internal view virtual override returns (string memory) {
		return _baseTokenURI;
	}

	function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
		return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
	}

	function setRoyalty(uint256 percentage, address receiver) external onlyOwner {
		royaltyPercentage = percentage;
		royaltyAddress = receiver;
	}

	function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royalty) {
		uint256 royaltyAmount = (salePrice * royaltyPercentage) / 10000;
		return (royaltyAddress, royaltyAmount);
	}

	function withdraw() public onlyOwner {
		uint balance = address(this).balance;
		payable(msg.sender).transfer(balance);
	}

	function withdrawAll() public onlyOwner {
		uint balance = address(this).balance;
		payable(creator1).transfer(balance * 3 / 100);
		payable(creator2).transfer(balance * 3 / 100);
		payable(creator3).transfer(balance * 4 / 100);
	}
}