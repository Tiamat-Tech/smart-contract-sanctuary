// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface LootInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface MLootInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Hazel5 is ERC721Enumerable, ReentrancyGuard, Ownable{
    using Counters for Counters.Counter;

	// Contract's state
	uint16 public constant TOTAL_SUPPLY = 20000;
	uint256 public constant MINT_PRICE = 0.001 ether;
	uint256 public royaltyPercentage;
	address public royaltyAddress;
	bool public isSaleActive = false;
	bool private _isLootPublicSaleActive = false;
	bool private _isWhitelistSaleActive = true;
	bool private _isSpecialSetMinted = false;
	string private _baseTokenURI;

	uint16 private constant _supplyLoot = 7776;
	uint16 private constant _supplyGiveaway = 224;
	uint16 private constant _supplyWhitelist = 1000;
	uint16 private constant _supplyMLoot = 10593;
	uint16 private constant _supplyGA = 400;
	uint16 private constant _supplySpecialSet = 7;

	// Total 5 group = loot, whitelist, mloot, ga, special
	Counters.Counter private _countTokenLoot;
	Counters.Counter private _countTokenWhitelist;
	Counters.Counter private _countTokenMLoot;
	Counters.Counter private _countTokenGA;
	uint16 private _tokenIdStartMLoot = 8001;
	uint16 private _tokenIdStartGA = 19594;
	uint16 private _tokenIdStartSpecialSet = 19994;

	mapping(address => bool) private _whitelist;
	mapping(address => uint256) private _giveawayList;
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
	event HazelMinted(uint256 indexed id, uint8 indexed fromTokenType, uint256 indexed fromTokenId, uint8 face, uint8 eyes, uint8 background);

	constructor() ERC721("Hazel5", "HZL") {}

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

	function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
		bytes4 _ERC165_ = 0x01ffc9a7;
		bytes4 _ERC721_ = 0x80ac58cd;
		bytes4 _ERC2981_ = 0x2a55205a;
		bytes4 _ERC721Metadata_ = 0x5b5e139f;
		return interfaceId == _ERC165_ || interfaceId == _ERC721_ || interfaceId == _ERC2981_ || interfaceId == _ERC721Metadata_;
	}

	function setRoyalty(uint256 percentage, address receiver) external onlyOwner {
		royaltyPercentage = percentage;
		royaltyAddress = receiver;
	}

	function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royalty) {
		uint256 royaltyAmount = (salePrice * royaltyPercentage) / 10000;
		return (royaltyAddress, royaltyAmount);
	}

	// Token ID 1 - 8000; 7836 & 7881 has been minted by dom
	function mintWithLoot(uint16 lootId, uint8 face, uint8 eyes, uint8 background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(lootId < 8001, "TOKEN_ID_OUT_OF_RANGE");
		require(lootContract.ownerOf(lootId) == msg.sender, "MUST_OWN_TOKEN_ID");
		require(MINT_PRICE <= msg.value, "WRONG_ETHER_VALUE");
		_checkTraits(face, eyes, background);

		_mintHazelEvent(msg.sender, lootId, 0, lootId, face, eyes, background);
		_countTokenLoot.increment();
	}

	// Token ID 7778-8000 ; except 7836 & 7881
	function mintGiveaway(uint256 lootId, uint8 face, uint8 eyes, uint8 background) public nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(lootId > 7777 && lootId < 8001, "TOKEN_ID_OUT_OF_RANGE");
		// Only allowed to mint specific loot id
		require(_giveawayList[msg.sender] == lootId, "ADDRESS_NOT_ELIGIBLE");
		_checkTraits(face, eyes, background);

		_mintHazelEvent(msg.sender, lootId, 0, lootId, face, eyes, background);
	}

	// Token ID 8,001 - 18993
	function mintWithWhitelist(uint256 mlootId, uint8 face, uint8 eyes, uint8 background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(_countTokenWhitelist.current() < _supplyWhitelist, "SOLD_OUT");
		require(_whitelist[msg.sender], "ADDRESS_NOT_WHITELISTED");
		require(MINT_PRICE <= msg.value, "WRONG_ETHER_VALUE");
		_checkMLoot(mlootId, msg.sender);
		_checkTraits(face, eyes, background);

		_mintHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), 1, mlootId, face, eyes, background);
		_countTokenMLoot.increment();
		_whitelist[msg.sender] = false;
		_claimedMLoot[mlootId] = true;
	}

	// Token ID 8,001 - 18993
	function mintWithMLoot(uint256 mlootId, uint8 face, uint8 eyes, uint8 background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(_countTokenMLoot.current() < (_supplyMLoot - _supplyWhitelist), "SOLD_OUT");
		require(MINT_PRICE <= msg.value, "WRONG_ETHER_VALUE");
		_checkMLoot(mlootId, msg.sender);
		_checkTraits(face, eyes, background);

		_mintHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), 1, mlootId, face, eyes, background);
		_countTokenMLoot.increment();
		_claimedMLoot[mlootId] = true;
	}

	// Token ID 19,994 - 20,000
	function mintSpecialSet() public nonReentrant onlyOwner {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(!_isSpecialSetMinted, "SPECIAL_SET_ALREADY_CLAIMED");

		for (uint256 index = 0; index < _supplySpecialSet; index++) {
			_mintHazel(msg.sender, _tokenIdStartSpecialSet + index);
		}

		_isSpecialSetMinted = true;
	}

	function multiMintWithLoot(uint256[] calldata lootIds, uint8[] calldata face, uint8[] calldata eyes, uint8[] calldata background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");

		for (uint256 index = 0; index < lootIds.length; index++) {
			uint256 id = lootIds[index];
			require(id < 8001, "TOKEN_ID_OUT_OF_RANGE");	
			require(lootContract.ownerOf(id) == msg.sender, "MUST_OWN_TOKEN_ID");
			require((MINT_PRICE * lootIds.length) <= msg.value, "WRONG_ETHER_VALUE");

			_checkTraits(face[index], eyes[index], background[index]);
			_mintHazelEvent(msg.sender, id, 0, id, face[index], eyes[index], background[index]);
			_countTokenLoot.increment();
		}
	}

	function multiMintWithMLoot(uint256[] calldata mlootIds, uint8[] calldata face, uint8[] calldata eyes, uint8[] calldata background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(_countTokenMLoot.current() + mlootIds.length < _supplyMLoot - _supplyWhitelist, "MAX_TOKEN_EXCEED");

		for (uint256 index = 0; index < mlootIds.length; index++) {
			uint256 id = mlootIds[index];
			require(id > 8000, "TOKEN_ID_OUT_OF_RANGE");	
			require(mlootContract.ownerOf(id) == msg.sender, "MUST_OWN_TOKEN_ID");
			require((MINT_PRICE * mlootIds.length) <= msg.value, "WRONG_ETHER_VALUE");

			_checkTraits(face[index], eyes[index], background[index]);
			_checkMLoot(id, msg.sender);

			_mintHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), 1, id, face[index], eyes[index], background[index]);
			_countTokenMLoot.increment();
			_claimedMLoot[id] = true;
		}
	}

	// Only used if the community decides to open the locked loot supply to public
	function mintWithLootPublic(uint256 lootId, uint8 face, uint8 eyes, uint8 background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(_isLootPublicSaleActive, "LOOT_PUBLIC_NOT_ACTIVE");
		require(lootId < 8001, "TOKEN_ID_OUT_OF_RANGE");
		require(MINT_PRICE <= msg.value, "WRONG_ETHER_VALUE");
		_checkTraits(face, eyes, background);

		_mintHazelEvent(msg.sender, lootId, 0, lootId, face, eyes, background);
		_countTokenLoot.increment();
	}

	function mintWithMLootPublic(uint256 mlootId, uint8 face, uint8 eyes, uint8 background) public payable nonReentrant {
		require(isSaleActive, "SALE_NOT_ACTIVE");
		require(!_isWhitelistSaleActive, "WHIETLIST_PUBLIC_NOT_ACTIVE");
		require(_countTokenMLoot.current() < _supplyMLoot + _supplyWhitelist, "SOLD_OUT");
		require(MINT_PRICE <= msg.value, "WRONG_ETHER_VALUE");
		_checkMLoot(mlootId, msg.sender);
		_checkTraits(face, eyes, background);

		_mintHazelEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), 1, mlootId, face, eyes, background);
		_countTokenMLoot.increment();
		_claimedMLoot[mlootId] = true;
	}

	function _mintHazelEvent(address _to, uint256 _tokenId, uint8 _tokenType, uint256 _fromTokenId, uint8 _face, uint8 _eyes, uint8 _background) private {
		_mintHazel(_to, _tokenId);
		emit HazelMinted(_tokenId, _tokenType, _fromTokenId, _face, _eyes, _background);
	}

	function _mintHazel(address _to, uint256 _tokenId) private {
		_safeMint(_to, _tokenId);
	}

	function _checkTraits(uint8 _face, uint8 _eyes, uint8 _background) private pure {
		// 12 type of face
		require(_face >= 0 && _face < 12, "TRAIT_OUT_OF_RANGE");
		// 12 type of eyes
		require(_eyes >= 0 && _eyes < 12, "TRAIT_OUT_OF_RANGE");
		// 8 type of background
		require(_background >= 0 && _background < 8, "TRAIT_OUT_OF_RANGE");
	}

	function _checkMLoot(uint256 mlootId, address _from) private view {
		require(mlootId > 8000, "TOKEN_ID_OUT_OF_RANGE");
		require(mlootContract.ownerOf(mlootId) == _from, "MUST_OWN_TOKEN_ID");
		require(!_claimedMLoot[mlootId], "MLOOT_ALREADY_CLAIMED");
	}

	function totalLootMinted() public view returns (uint256) {
		return _countTokenLoot.current();
	}

	function toalWhitelistMinted() public view returns (uint256) {
		return _countTokenWhitelist.current();
	}

	function totalMLootMinted() public view returns (uint256) {
		return _countTokenMLoot.current();
	}

	function totalGAMinted() public view returns (uint256) {
		return _countTokenGA.current();
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