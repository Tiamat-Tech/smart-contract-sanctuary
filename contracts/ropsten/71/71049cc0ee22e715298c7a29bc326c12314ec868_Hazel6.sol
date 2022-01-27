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

contract Hazel6 is ERC721, IERC2981, ReentrancyGuard, Ownable{
	using Counters for Counters.Counter;

	// Project info
	uint256 public constant TOTAL_SUPPLY = 20000;
	uint256 public constant MINT_PRICE = 0.001 ether;

	// Royalty
	uint256 public royaltyPercentage;
	address public royaltyAddress;
	
	// Contrat's state
	bool public isSaleActive = false;
	bool private _isLootPublicSaleActive = false;
	bool private _isWhitelistSaleActive = true;
	bool private _isSpecialSetMinted = false;
	string private _baseTokenURI;

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
	event HazelMinted(uint256 indexed id, string indexed fromTokenType, uint256 indexed fromTokenId, uint256[4] traits);

	constructor() ERC721("Hazel6", "HZL6") {}

	function setSale(bool saleState) external onlyOwner {
		isSaleActive = saleState;
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

	modifier saleActive() {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		_;
	}

	modifier ownLoot(uint256 lootId) {
		require(lootId < 8001, "TOKEN_ID_OUT_OF_RANGE");
		require(lootContract.ownerOf(lootId) == msg.sender, "MUST_OWN_TOKEN_ID");
		_;
	}

	modifier ownMLoot(uint256 mlootId) {
		require(mlootId > 8000, "TOKEN_ID_OUT_OF_RANGE");
		require(mlootContract.ownerOf(mlootId) == msg.sender, "MUST_OWN_TOKEN_ID");
		require(!_claimedMLoot[mlootId], "MLOOT_ALREADY_CLAIMED");
		_;
	}

	modifier isPaymentValid(uint256 amount) {
		require((MINT_PRICE * amount) <= msg.value, "WRONG_ETHER_VALUE");
		_;
	}

	modifier isTraitValid(uint256[4] calldata traits) {
		// 12 type of face
		require(traits[0] >= 0 && traits[0] < 12, "FACE_TRAIT_OUT_OF_RANGE");
		// 12 type of eyes
		require(traits[1] >= 0 && traits[1] < 12, "EYES_TRAIT_OUT_OF_RANGE");
		// 8 type of background
		require(traits[2] >= 0 && traits[2] < 8, "BACKGROUND_TRAIT_OUT_OF_RANGE");
		// 4 type of left hand
		require(traits[3] >= 0 && traits[3] < 4, "LEFT_HAND_TRAIT_OUT_OF_RANGE");
		_;
	}

	modifier isMLootSupplyAvailable() {
		require(_countTokenMLoot.current() < (_supplyMLoot - _supplyWhitelist), "SOLD_OUT");
		_;
	}

	// Token ID 1 - 8000; 7836 & 7881 has been minted by dom
	function mintWithLoot(uint256 lootId, uint256[4] calldata traits) public payable
		nonReentrant
		saleActive
		ownLoot(lootId)
		isPaymentValid(1)
		isTraitValid(traits) {
		_mintHazelEvent(msg.sender, lootId, "loot", lootId, traits);
		_countTokenLoot.increment();
	}

	// Token ID 8,001 - 18993
	function mintWithMLoot(uint256 mlootId, uint256[4] calldata traits) public payable
		nonReentrant 
		saleActive
		isMLootSupplyAvailable
		ownMLoot(mlootId)
		isPaymentValid(1)
		isTraitValid(traits) {
		_mintHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), "mloot", mlootId, traits);
		_countTokenMLoot.increment();
		_claimedMLoot[mlootId] = true;
	}

	function _mintHazelEvent(address _to, uint256 _tokenId, string memory _tokenType, uint256 _fromTokenId, uint256[4] calldata traits) private {
		_mintHazel(_to, _tokenId);
		emit HazelMinted(_tokenId, _tokenType, _fromTokenId, traits);
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