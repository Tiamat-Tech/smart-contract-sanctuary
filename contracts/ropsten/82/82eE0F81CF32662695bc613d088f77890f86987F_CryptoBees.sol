//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IHoney.sol";
import "./IHive.sol";
import "./Base64.sol";

contract CryptoBees is ERC721Enumerable, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    // mint price ETH
    uint256 public constant MINT_PRICE = .02 ether;
    // mint price HONEY
    uint256 public constant MINT_PRICE_HONEY = 3000 ether;
    // mint price WOOL
    uint256 public constant MINT_PRICE_WOOL = 3000 ether;
    // mint price ETH discount
    uint256 public constant MINT_PRICE_DISCOUNT = .055 ether;

    address private constant BEEKEEPER_1 = 0x8F0025FF54879B322582CCBebB1f391b1d5a1FBf;
    address private constant BEEKEEPER_2 = 0x55Cb7Cf904070e41441BC8c981fDE03Cea42585d;
    address private constant BEEKEEPER_3 = 0xF40d7CdE92Bc1C3CE72bC41E913e9Ba6023B9F37;
    address private constant BEEKEEPER_4 = 0xA6b42f9D0eb06AA40FcAa2E368cED1A8aa6761b5;

    IHoney private honeyContract;
    IHive private hiveContract;

    // max number of tokens that can be minted
    uint256 public constant MAX_TOKENS = 40000;
    // number of tokens that can be claimed for ETH
    uint256 public constant PAID_TOKENS = 10000;
    // number of tokens have been minted so far
    uint16 public minted;

    /// @notice game controllers they can access special functions
    mapping(address => bool) public controllers;
    /// @notice whitelisted addresses
    mapping(address => bool) public whitelisted;

    /// @notice controls if mintWithEthPresale is paused
    bool public mintWithEthPresalePaused = true;
    /// @notice controls if mintWithEth is paused
    bool public mintWithEthPaused = true;
    /// @notice controls if mintFromController is paused
    bool public mintFromControllerPaused = true;
    /// @notice controls if token reveal is paused
    bool public revealPaused = true;

    struct Token {
        uint8 _type;
        uint32 pot;
        uint48 lastAttackTimestamp;
    }

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => Token) public tokenData;

    event Mint(address indexed owner, uint256 tokenId, uint256 _type);

    /**
     * instantiates contract and rarity tables
     */
    constructor(address _HONEY_CONTRACT, address _HIVE_CONTRACT) ERC721("CryptoBees Game", "CRYPTOBEES") {
        honeyContract = IHoney(_HONEY_CONTRACT);
        hiveContract = IHive(_HIVE_CONTRACT);
    }

    /// ==== Modifiers
    modifier onlyControllers() {
        require(controllers[_msgSender()], "ONLY_CONTROLLERS");
        _;
    }

    function setHoneyContract(address _HONEY_CONTRACT) external onlyOwner {
        honeyContract = IHoney(_HONEY_CONTRACT);
    }

    function setHiveContract(address _HIVE_CONTRACT) external onlyOwner {
        hiveContract = IHive(_HIVE_CONTRACT);
    }

    //nonReentrant
    function increateTokensPot(uint256 tokenId, uint32 amount) external {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        require(_msgSender() == address(hiveContract), "DONT CHEAT!");
        tokenData[tokenId].pot += amount;
    }

    //nonReentrant
    function updateTokensLastAttack(uint256 tokenId, uint48 timestamp) external {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        require(_msgSender() == address(hiveContract), "DONT CHEAT!");
        tokenData[tokenId].lastAttackTimestamp = timestamp;
    }

    /**
     * mint a token - 90% Bee, 9% Bear, 1% Beekeeper
     */
    function mintForEth(uint256 amount, bool stake) external payable whenNotPaused nonReentrant {
        mintCheck(amount, true);
        for (uint256 i = 0; i < amount; i++) {
            minted++;
            mintRandom(minted);
        }
        if (stake) {}
    }

    // does this need payable??
    //
    //
    function mintForHoney(uint256 amount, bool stake) external whenNotPaused nonReentrant {
        mintCheck(amount, false);
        uint256 totalHoneyCost = 0;
        for (uint256 i = 0; i < amount; i++) {
            minted++;
            totalHoneyCost += MINT_PRICE_HONEY;
            mintRandom(minted);
        }
        if (stake) {}
        honeyContract.burn(msg.sender, totalHoneyCost);
    }

    function mintCheck(uint256 amount, bool withETH) private {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 10, "Invalid mint amount");
        if (withETH && minted < PAID_TOKENS) {
            require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
            require(amount * MINT_PRICE == msg.value, "Invalid payment amount");
        }
    }

    function mintRandom(uint256 tokenId) private {
        uint256 seed = random(tokenId);
        uint256 num = ((seed & 0xFFFF) % 100);
        if (num == 0) tokenData[tokenId]._type = 0;
        else if (num < 10) tokenData[tokenId]._type = 1;
        else tokenData[tokenId]._type = 2;
        _safeMint(_msgSender(), tokenId);
        emit Mint(_msgSender(), tokenId, tokenData[tokenId]._type);
    }

    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed)));
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _transfer(from, to, tokenId);
    }

    function isWhitelisted(address who) external view returns (bool) {
        return whitelisted[who];
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficent balance");
        _widthdraw(BEEKEEPER_1, ((balance * 25) / 100));
        _widthdraw(BEEKEEPER_2, ((balance * 25) / 100));
        _widthdraw(BEEKEEPER_3, ((balance * 25) / 100));
        _widthdraw(BEEKEEPER_4, ((balance * 25) / 100));
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Failed to widthdraw Ether");
    }

    /// @notice withdraw ERC20 tokens from the contract
    /// people always randomly transfer ERC20 tokens to the
    /// @param erc20TokenAddress the ERC20 token address
    /// @param recipient who will get the tokens
    /// @param amount how many tokens
    function withdrawERC20(
        address erc20TokenAddress,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IERC20 erc20Contract = IERC20(erc20TokenAddress);
        bool sent = erc20Contract.transfer(recipient, amount);
        require(sent, "ERC20_WITHDRAW_FAILED");
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /** RENDER */

    function getTokenIds(address _owner) public view returns (uint256[] memory _tokensOfOwner) {
        _tokensOfOwner = new uint256[](balanceOf(_owner));
        for (uint256 i; i < balanceOf(_owner); i++) {
            _tokensOfOwner[i] = tokenOfOwnerByIndex(_owner, i);
        }
    }

    function getTokenType(uint256 tokenId) external view returns (uint256) {
        return tokenData[tokenId]._type;
    }

    function getTokenTextType(uint256 tokenId) external view returns (string memory) {
        return _getTokenTextType(tokenId);
    }

    function _getTokenTextType(uint256 tokenId) private view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        if (tokenData[tokenId]._type == 0) return "BEEKEEPER";
        else if (tokenData[tokenId]._type == 1) return "BEAR";
        else return "BEE";
    }

    function getTokenImage(uint256 tokenId) private view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        if (tokenData[tokenId]._type == 0) return "QmTUuGDbndWZDYYr6pE1aeutZLpSuZi44KMZxeUw1VB2D8";
        else if (tokenData[tokenId]._type == 1) return "QmVPMv3Kxg94vAJo4fQY2FGnYTYp4RM1dq7anwr9psbz9P";
        else return "QmfCnnjNDndTuRZLZFJhLVtQ8m533pEnBis4Y2NH3BvZdF";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");

        string memory textType = _getTokenTextType(tokenId);
        string memory image = getTokenImage(tokenId);
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "',
                textType,
                " #",
                uint256(tokenId).toString(),
                '", "type": "',
                textType,
                '", "trait": "',
                uint256(tokenData[tokenId]._type).toString(),
                '", "description": "',
                '","image": "',
                image,
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
    }
}