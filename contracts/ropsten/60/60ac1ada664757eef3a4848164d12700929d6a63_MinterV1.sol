// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract MinterV1 is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using MerkleProofUpgradeable for bytes32[];

    struct Character {
        string name;
        string description;
        string imageURI;
        uint256 hp;
        uint256 maxHp;
        uint256 attackDamage;
        uint256 maxAttackDamage;
        uint256 level;
        uint256 maxLevel;
    }

    struct Boss {
        string name;
        string description;
        string imageURI;
        uint256 hp;
        uint256 maxHp;
        uint256 attackDamage;
        uint256 maxAttackDamage;
    }

    event CharacterMinted(uint256 characterId);
    event NewBoss(string bossName);

    bytes32 public constant GAME_ADDRESS = keccak256("GAME_ADDRESS");

    mapping(uint256 => Character) public characters;
    mapping(uint256 => address) public characterToOwner;
    mapping(address => uint256) public whitelistClaimed;

    CountersUpgradeable.Counter private _tokenIds;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_PER_TX = 10;
    uint256 public constant WL_MINT_LIMIT = 3;
    uint256 public MINT_PRICE;

    bytes32 private merkleRoot;
    string private ipfsHash;
    bool public saleActive;
    bool public whitelistSaleActive;

    function initialize() public initializer {
        __ERC721_init("Game", "GAME");
        __ERC721Enumerable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        MINT_PRICE = 40 ether;
        saleActive = false;
        whitelistSaleActive = false;

        _tokenIds.increment();
        // _mintTokens(100, msg.sender);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Modifiers
    modifier validateMint(uint256 _tokenAmount) {
        require(MAX_PER_TX >= _tokenAmount, "Exceeds max per tx");
        require(MAX_SUPPLY >= _tokenIds.current().add(_tokenAmount), "Exceeds max supply");
        require(MINT_PRICE.mul(_tokenAmount) == msg.value, "Incorrect value sent");
        _;
    }

    // Admin functions
    function setIpfsHash(string memory _newHash) public onlyOwner {
        ipfsHash = _newHash;
    }

    function setMintPrice(uint256 _newPrice) public onlyOwner {
        MINT_PRICE = _newPrice;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function flipSaleState() public onlyOwner {
        saleActive = !saleActive;
    }

    function flipWhitelistState() public onlyOwner {
        whitelistSaleActive = !whitelistSaleActive;
    }

    function withdrawAll() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Internal functions
    function _mintTokens(uint256 _tokenAmount, address _to) private {
        for (uint256 i = 0; i < _tokenAmount; i++) {
            uint256 tokenId = _tokenIds.current();

            characters[tokenId] = Character({
                name: string(abi.encodePacked("NFTGame #", tokenId.toString())),
                description: "NFTGame is a on-chain NFT game",
                imageURI: string(abi.encodePacked(ipfsHash, "/", tokenId.toString(), ".png")),
                hp: 100,
                maxHp: 500,
                attackDamage: 50,
                maxAttackDamage: 250,
                level: 1,
                maxLevel: 5
            });

            _safeMint(_to, tokenId);
            characterToOwner[tokenId] = msg.sender;

            _tokenIds.increment();

            emit CharacterMinted(tokenId);
        }
    }

    // Public functions
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "No character with that ID");

        Character memory char = characters[_tokenId];

        string memory strHp = StringsUpgradeable.toString(char.hp);
        string memory strMaxHp = StringsUpgradeable.toString(char.maxHp);
        string memory strAttackDamage = StringsUpgradeable.toString(char.attackDamage);
        string memory strMaxAttackDamage = StringsUpgradeable.toString(char.maxAttackDamage);
        string memory strLevel = StringsUpgradeable.toString(char.level);
        string memory strMaxLevel = StringsUpgradeable.toString(char.maxLevel);

        string memory json = Base64Upgradeable.encode(
            abi.encodePacked(
                '{"name": "',
                char.name,
                '", "description": "',
                char.description,
                '", "external_url": "https://example.com/gallery/',
                _tokenId.toString(),
                '", "image": "',
                char.imageURI,
                '", "attributes": [{ "trait_type": "Health Points", "value": ',
                strHp,
                ', "max_value": ',
                strMaxHp,
                ' }, { "trait_type": "Attack Damage", "value": ',
                strAttackDamage,
                ', "max_value": ',
                strMaxAttackDamage,
                ' }, { "trait_type": "Level", "value": ',
                strLevel,
                ', "max_value": ',
                strMaxLevel,
                " }] }"
            )
        );

        string memory output = string(abi.encodePacked("data:application/json;base64,", json));

        return output;
    }

    function mintWhitelist(uint256 _tokenAmount, bytes32[] calldata _proof) public payable validateMint(_tokenAmount) {
        require(whitelistSaleActive, "Whitelist sale is not active");
        require(whitelistClaimed[msg.sender] < WL_MINT_LIMIT, "Already claimed all tokens");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProofUpgradeable.verify(_proof, merkleRoot, leaf), "Not whitelisted");

        whitelistClaimed[msg.sender].add(_tokenAmount);

        _mintTokens(_tokenAmount, msg.sender);
    }

    function mint(uint256 _tokenAmount) public payable validateMint(_tokenAmount) {
        require(saleActive, "Sale is not active");

        _mintTokens(_tokenAmount, msg.sender);
    }
}