// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface LootInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface MLootInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface GAInterface {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract HyperTest3 is ERC721, IERC2981, ReentrancyGuard, Ownable{
	using Counters for Counters.Counter;

	// Project info
	uint256 public constant TOTAL_SUPPLY = 20000;
	uint256 public constant MINT_PRICE = 0.001 ether;

	// Royalty
	uint256 public royaltyPercentage;
	address public royaltyAddress;
	
	// Contrat's state
	bool public isPresaleActive = false;
	bool public isPublicSaleActive = false;
	bool private _isSpecialSetMinted = false;
	string private _baseTokenURI;
	bytes32 public hyperlistMerkleRoot;

	// 3 different types of bag used to mint HyperLoot
	uint16 private constant _lootType = 0;
	uint16 private constant _mlootType = 1;
	uint16 private constant _gaType = 2;

	// Total 5 group = loot, hyperlist, mloot, ga, special set
	// Supply for different groups
	uint16 private constant _supplyLoot = 7776;
	uint16 private constant _supplyGiveaway = 224;
	uint16 private constant _supplyHyperlist = 1000;
	uint16 private constant _supplyGA = 400;
	uint16 private constant _supplySpecialSet = 7;
	uint16 private _supplyMLoot = 10593;

	// Token count for different groups
	uint16 private _tokenIdStartMLoot = 8001;
	uint16 private _tokenIdStartGA = 19594;
	uint16 private _tokenIdStartSpecialSet = 19994;
	Counters.Counter private _countTokenLoot;
	Counters.Counter private _countTokenMLoot;
	Counters.Counter private _countTokenGA;

	// Specific address claimable info
	mapping(address => bool) private _hyperlist;
	mapping(address => uint256) private _giveawayList;
	mapping(address => bool) private _claimedHyperlist;

	// Claimed mloot and ga states
	mapping(uint256 => bool) private _claimedMLoot;
	mapping(uint256 => bool) private _claimedGA;

	// Creators address
	address creator1 = 0xf3C121112f04Fc00d6e6F8e0a4c3957cA4f10D2E;
	address creator2 = 0x742b05eA502270FE9075f53806A887b33d74081E;
	address creator3 = 0xF1F41C9527e496C7fbd53e74b8F50B18f938014F;

	// Loot Contract
	address private lootAddress = 0x84598615a040824ccA80e51f4536E92dd041a564;
	LootInterface lootContract = LootInterface(lootAddress);

	// More Loot Contract
	address private mlootAddress = 0xe1B199772EC31BBc91cAAdFc0f7328D895ae3Ba1;
	MLootInterface mlootContract = MLootInterface(mlootAddress);

	// Genesis Adventurer Contract
	address private gaAddress = 0x8dB687aCEb92c66f013e1D614137238Cc698fEdb;
	GAInterface gaContract = GAInterface(gaAddress);

	// TokenType = [Loot, MLoot, GA, Giveaway]
	event HyperLootMinted(uint256 indexed id, uint256 indexed fromTokenType, uint256 indexed fromTokenId, uint8[4] traits);

	constructor() ERC721("HyperTest3", "HYPERT3") {}

	// ————————————————— //
	// ——— Modifiers ——— //
	// ————————————————— //

	modifier presaleActive() {
		require(isPresaleActive, "PRESALE_NOT_ACTIVE");
		_;
	}

	modifier publicSaleActive() {
		require(isPublicSaleActive, "PUBLIC_SALE_NOT_ACTIVE");
		_;
	}

	modifier isPaymentValid(uint256 amount) {
		require((MINT_PRICE * amount) <= msg.value, "WRONG_ETHER_VALUE");
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
	// Limit mloot hodlers to mint only 1 hyperloot if in hyperlist
	function mintPresale(uint256[] calldata bagIds, uint16[] calldata bagType, uint8[] calldata traits, bytes32[] calldata merkleProof) external payable
		nonReentrant
		presaleActive
		isPaymentValid(bagIds.length) {
			_checkTraitsCount(bagIds.length, bagType.length, traits.length);

			for (uint8 index = 0; index < bagIds.length; index++) {
				// array format = [face, eyes, bg, left]
				uint8 face = traits[index * 4];
				uint8 eyes = traits[index * 4 + 1];
				uint8 bg = traits[index * 4 + 2];
				uint8 left = traits[index * 4 + 3];
				_checkTraitsValid(face, eyes, bg, left);

				uint bagId = bagIds[index];
				if (bagType[index] == _lootType) {
					// _checkLootOwner(bagId);

					_mintHyperLootEvent(msg.sender, bagId, _lootType, bagId, face, eyes, bg, left);
					_countTokenLoot.increment();
				} else if (bagType[index] == _mlootType) {
					// Check if address is in hyperlist
					_checkMerkleProof(merkleProof, hyperlistMerkleRoot, msg.sender);
					// Check if user already claimed hyperlist
					_checkHyperlistClaimed(msg.sender);
					// Check mLoot
					// _checkMLootOwner(bagId);

					_mintHyperLootEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), _mlootType, bagId, face, eyes, bg, left);
					_claimMLoot(bagId);
					_claimedHyperlist[msg.sender] = true;
				} else if (bagType[index] == _gaType) {
					_checkGASupply();
					_checkGAOwner(bagId);

					_mintHyperLootEvent(msg.sender, _tokenIdStartGA + _countTokenGA.current(), _gaType, bagId, face, eyes, bg, left);
					_claimGA(bagId);
				}
			}
	}

	// Hodlers of Loot, mLoot, GA can mint any amount
	function mintPublic(uint256[] calldata bagIds, uint16[] calldata bagType, uint8[] calldata traits) external payable
		nonReentrant
		publicSaleActive
		isPaymentValid(bagIds.length) {
			_checkTraitsCount(bagIds.length, bagType.length, traits.length);

			for (uint8 index = 0; index < bagIds.length; index++) {
				// array format = [face, eyes, bg, left]
				uint8 face = traits[index * 4];
				uint8 eyes = traits[index * 4 + 1];
				uint8 bg = traits[index * 4 + 2];
				uint8 left = traits[index * 4 + 3];
				_checkTraitsValid(face, eyes, bg, left);

				uint bagId = bagIds[index];
				if (bagType[index] == _lootType) {
					// _checkLootOwner(bagId);

					_mintHyperLootEvent(msg.sender, bagId, _lootType, bagId, face, eyes, bg, left);
					_countTokenLoot.increment();
				} else if (bagType[index] == _mlootType) {
					_checkMLootSupply();
					// _checkMLootOwner(bagId);

					_mintHyperLootEvent(msg.sender, _tokenIdStartMLoot + _countTokenMLoot.current(), _mlootType, bagId, face, eyes, bg, left);
					_claimMLoot(bagId);
				} else if (bagType[index] == _gaType) {
					_checkGASupply();
					_checkGAOwner(bagId);

					_mintHyperLootEvent(msg.sender, _tokenIdStartGA + _countTokenGA.current(), _gaType, bagId, face, eyes, bg, left);
					_claimGA(bagId);
				}
			}
	}

	// Token ID 7778-8000; except 7836 & 7881
	function mintGiveaway(uint256 lootId, uint8 faceId, uint8 eyesId, uint8 backgroundId, uint8 leftHandId) external
		nonReentrant
		isGiveawaySupplyAvailable(lootId) {
		_checkTraitsValid(faceId, eyesId, backgroundId, leftHandId);
		_mintHyperLootEvent(msg.sender, lootId, _lootType, lootId, faceId, eyesId, backgroundId, leftHandId);
		_countTokenLoot.increment();
	}

	// Token ID 19,994 - 20,000
	function mintSpecialSet() external nonReentrant onlyOwner {
		require(!_isSpecialSetMinted, "SPECIAL_SET_ALREADY_CLAIMED");

		for (uint256 index = 0; index < _supplySpecialSet; index++) {
			_mintToken(msg.sender, _tokenIdStartSpecialSet + index);
		}

		_isSpecialSetMinted = true;
	}

	// ———————————————————————— //
	// ——— Helper Functions ——— //
	// ———————————————————————— //

	function _checkMerkleProof(bytes32[] calldata merkleProof, bytes32 root, address from) private pure {
		require(MerkleProof.verify(merkleProof, root, keccak256(abi.encodePacked(from))),"ADDRESS_NOT_ELIGIBLE");
	}

	function _checkHyperlistClaimed(address from) private view {
		require(!_claimedHyperlist[from], "ADDRESS_HYPERLIST_QUOTA_EXCEED");
	}

	function _checkTraitsCount(uint256 bagIds, uint256 bagType, uint256 traits) private pure {
		require(bagIds == bagType, "BAG_TYPE_LENGTH_MISMATCH");
		require(bagIds == traits / 4, "TRAIT_LENGTH_MISMATCH");
	}

	function _checkHyperlist() private view {
		require(_countTokenMLoot.current() < _supplyHyperlist, "HYPERLIST_SOLD_OUT");
		require(_hyperlist[msg.sender], "ADDRESS_NOT_IN_HYPERLIST");
	}

	function _checkLoot(uint256 lootId) private view {
		// Token ID 1 - 8000; 7836 & 7881 has been minted by dom
		require(lootId < 8001, "LOOT_TOKEN_ID_OUT_OF_RANGE");
	}
 
	function _checkLootOwner(uint256 lootId) private view {
		// Token ID 1 - 8000; 7836 & 7881 has been minted by dom
		require(lootId < 8001, "LOOT_TOKEN_ID_OUT_OF_RANGE");
		require(lootContract.ownerOf(lootId) == msg.sender, "MUST_OWN_TOKEN_ID");
	}

	function _checkMLootOwner(uint256 mlootId) private view {
		// Token ID 8,001 - 18993
		require(mlootId > 8000, "MLOOT_TOKEN_ID_OUT_OF_RANGE");
		require(mlootContract.ownerOf(mlootId) == msg.sender, "MUST_OWN_TOKEN_ID");
		require(!_claimedMLoot[mlootId], "MLOOT_ALREADY_CLAIMED");
	}

	function _checkGAOwner(uint256 gaId) private view {
		require(gaContract.ownerOf(gaId) == msg.sender, "MUST_OWN_TOKEN_ID");
		require(!_claimedGA[gaId], "GA_ALREADY_CLAIMED");
	}

	function _checkMLootSupply() private view {
		require(_countTokenMLoot.current() < (_supplyMLoot - _supplyHyperlist), "MLOOT_SOLD_OUT");
	}

	function _checkGASupply() private view {
		require(_countTokenGA.current() < _supplyGA, "GA_SOLD_OUT");
	}

	function _checkTraitsValid(uint8 faceId, uint8 eyesId, uint8 backgroundId, uint8 leftHandId) private pure {
		_checkFaceTrait(faceId);
		_checkEyesTrait(eyesId);
		_checkBackgroundTrait(backgroundId);
		_checkLeftHandTrait(leftHandId);
	}

	function _checkFaceTrait(uint8 faceId) private pure {
		// 12 type of face
		require(faceId >= 0 && faceId < 12, "FACE_TRAIT_OUT_OF_RANGE");
	}

	function _checkEyesTrait(uint8 eyesId) private pure {
		// 12 type of eyes
		require(eyesId >= 0 && eyesId < 12, "EYES_TRAIT_OUT_OF_RANGE");
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

	function _claimGA(uint256 gaId) private {
		_countTokenGA.increment();
		_claimedGA[gaId] = true;
	}

	function _mintHyperLootEvent(address _to, uint256 _tokenId, uint256 _tokenType, uint256 _fromTokenId, uint8 faceIds, uint8 eyesIds, uint8 backgroundIds, uint8 leftHandIds) private {
		_mintToken(_to, _tokenId);
		emit HyperLootMinted(_tokenId, _tokenType, _fromTokenId, [faceIds, eyesIds, backgroundIds, leftHandIds]);
	}

	function _mintToken(address _to, uint256 _tokenId) private {
		_safeMint(_to, _tokenId);
	}

	function totalLootMinted() public view returns (uint256) {
		return _countTokenLoot.current();
	}

	function totalMLootMinted() public view returns (uint256) {
		return _countTokenMLoot.current();
	}

	function totalGAMinted() public view returns (uint256) {
		return _countTokenGA.current();
	}
	
	function totalSupply() public view returns (uint256) {
		return _countTokenLoot.current() + _countTokenMLoot.current() + _countTokenGA.current() + _supplySpecialSet;
	}

	function isLootClaimed(uint256 lootId) public view {
		require (!_exists(lootId), "LOOT_ALREADY_CLAIMED");
	}

	function isMLootClaimed(uint256 mlootId) public view {
		require(!_claimedMLoot[mlootId], "MLOOT_ALREADY_CLAIMED");
	}

	function isGAClaimed(uint256 gaId) public view {
		require(!_claimedGA[gaId], "GA_ALREADY_CLAIMED");
	}

	// ————————————————————————————— //
	// ——— Admin/Owner Functions ——— //
	// ————————————————————————————— //

	function setPresale(bool saleState) external onlyOwner {
		isPresaleActive = saleState;
	}

	function setPublicSale(bool saleState) external onlyOwner {
		isPublicSaleActive = saleState;
		isPresaleActive = false;

		// Move unminted hyperlist supply to public
		_supplyMLoot = uint16(_supplyMLoot + _supplyHyperlist - _countTokenMLoot.current());
	}

	function setHyperlist(address[] calldata addresses) external onlyOwner {
		for (uint256 i = 0; i < addresses.length; i++) {
			_hyperlist[addresses[i]] = true;
		}
	}

	function setMerkleRoot(bytes32 root) external onlyOwner {
		hyperlistMerkleRoot = root;
	}

	function resetHyperlistClaim(address from) external onlyOwner {
		// Temporary function for testing only
		_claimedHyperlist[from] = false;
	}

	function setGiveaway(address[] calldata addresses, uint256[] calldata lootIds) external onlyOwner {
		for (uint256 i = 0; i < addresses.length; i++) {
			_giveawayList[addresses[i]] = lootIds[i];
		}
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