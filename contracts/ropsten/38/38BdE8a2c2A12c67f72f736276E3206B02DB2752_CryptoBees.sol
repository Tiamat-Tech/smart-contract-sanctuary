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

import "./ICryptoBees.sol";
import "./IHoney.sol";
import "./IHive.sol";
import "./Traits.sol";
import "./Randomizer.sol";
import "./IAttack.sol";

contract CryptoBees is ICryptoBees, ERC721Enumerable, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    address private constant BEEKEEPER_1 = 0x8F0025FF54879B322582CCBebB1f391b1d5a1FBf;
    address private constant BEEKEEPER_2 = 0x55Cb7Cf904070e41441BC8c981fDE03Cea42585d;
    address private constant BEEKEEPER_3 = 0xF40d7CdE92Bc1C3CE72bC41E913e9Ba6023B9F37;
    address private constant BEEKEEPER_4 = 0xA6b42f9D0eb06AA40FcAa2E368cED1A8aa6761b5;

    IERC20 private woolContract = IERC20(0x8355DBE8B0e275ABAd27eB843F3eaF3FC855e525);
    IHoney private honeyContract;
    IHive private hiveContract;
    Randomizer private randomizerContract;
    Traits private traitsContract;
    IAttack private attackContract;

    uint32[] private unrevealedTokens;
    uint256 private unrevealedTokenIndex;
    // number of tokens have been minted so far
    uint256 public minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => Token) public tokenData;

    event Mint(address indexed owner, uint256 tokenId, uint256 blockNumber);

    /**
     * instantiates contract and rarity tables
     */
    constructor() ERC721("CryptoBees Game", "CRYPTOBEES") {}

    /// ==== Modifiers

    modifier requireContractsSet() {
        require(address(honeyContract) != address(0) && address(hiveContract) != address(0) && address(randomizerContract) != address(0), "Contracts not set");
        _;
    }

    function setContracts(
        address honey,
        address hive,
        address traits,
        address attack,
        address rand
    ) external onlyOwner {
        honeyContract = IHoney(honey);
        traitsContract = Traits(traits);
        hiveContract = IHive(hive);
        attackContract = IAttack(attack);
        randomizerContract = Randomizer(rand);
    }

    /**
     * mint a token - 90% Bee, 9% Bear, 1% Beekeeper
     */
    function mintForEth(uint256 amount) external payable whenNotPaused nonReentrant {
        traitsContract.mintForEth(_msgSender(), amount, minted, msg.value);
    }

    function mintForEthWhitelist(uint256 amount, bytes32[] calldata _merkleProof) external payable whenNotPaused nonReentrant {
        traitsContract.mintForEthWhitelist(_msgSender(), amount, minted, msg.value, _merkleProof);
    }

    function mintForHoney(uint256 amount) external whenNotPaused nonReentrant {
        traitsContract.mintForHoney(_msgSender(), amount, minted);
    }

    function mintForWool(uint256 amount) external whenNotPaused nonReentrant {
        uint256 totalCost = traitsContract.mintForWool(_msgSender(), amount, minted);
        woolContract.transferFrom(msg.sender, owner(), totalCost);
    }

    function mint(address _owner, uint256 tokenId) external {
        require(_msgSender() == address(traitsContract), "DONT CHEAT!");
        if (tokenId > 1) randomizerContract.revealToken(block.number);
        unrevealedTokens.push(uint32(block.number));
        minted = tokenId;
        _safeMint(_owner, tokenId);
        emit Mint(_owner, tokenId, block.number);
    }

    function getMinted() external view returns (uint256 m) {
        m = minted;
    }

    /**
     * enables owner to pause / unpause minting
     */

    function getUnrevealed(uint256 index) external view returns (uint256) {
        uint256 i = index > 0 ? index : unrevealedTokenIndex;
        if (i < unrevealedTokens.length) return unrevealedTokens[i];
        else return block.number;
    }

    function getUnrevealedIndex() external view returns (uint256) {
        return unrevealedTokenIndex;
    }

    function setUnrevealedIndex(uint256 index) external {
        require(_msgSender() == address(randomizerContract) || _msgSender() == owner(), "DONT CHEAT!");
        if (index < minted) {
            unrevealedTokenIndex = index;
        }
    }

    function pushToUnrevealedToken(uint256 blockNumber) external {
        require(_msgSender() == address(randomizerContract) || _msgSender() == owner(), "DONT CHEAT!");
        unrevealedTokens.push(uint32(blockNumber));
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    function setTokenType(uint256 tokenId, uint8 _type) external {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        require(_msgSender() == address(randomizerContract), "DONT CHEAT!");
        tokenData[tokenId]._type = _type;
    }

    //nonReentrant
    function increaseTokensPot(uint256 tokenId, uint32 amount) external {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        require(_msgSender() == address(attackContract), "DONT CHEAT!");
        tokenData[tokenId].pot += amount;
    }

    //nonReentrant
    function updateTokensLastAttack(
        uint256 tokenId,
        uint48 timestamp,
        uint48 till
    ) external {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        require(_msgSender() == address(attackContract), "DONT CHEAT!");
        tokenData[tokenId].lastAttackTimestamp = timestamp;
        tokenData[tokenId].cooldownTillTimestamp = till;
    }

    function getTokenIds(address _owner) public view returns (uint256[] memory _tokensOfOwner) {
        _tokensOfOwner = new uint256[](balanceOf(_owner));
        for (uint256 i; i < balanceOf(_owner); i++) {
            _tokensOfOwner[i] = tokenOfOwnerByIndex(_owner, i);
        }
    }

    function getOwnerOf(uint256 tokenId) external view returns (address) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        return ownerOf(tokenId);
    }

    function doesExist(uint256 tokenId) external view returns (bool exists) {
        exists = _exists(tokenId);
    }

    function getTokenData(uint256 tokenId) external view returns (Token memory token) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        token = tokenData[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        return traitsContract.tokenURI(tokenId);
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

    function performTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        // Hardcode the Hive's approval so that users don't have to waste gas approving
        if (_msgSender() != address(hiveContract)) require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function performSafeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        // Hardcode the Hive's approval so that users don't have to waste gas approving
        if (_msgSender() != address(hiveContract)) require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, "");
    }
}