// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract PlaceholderNFT is ERC721, Ownable, PaymentSplitter {
    using Counters for Counters.Counter;

    uint256 constant MAX_SUPPLY = 8888;

    uint256 public PRE_SALE_PRICE = 0.05 ether;
    uint256 public PUBLIC_SALE_PRICE = 0.06 ether;

    uint256 public MAX_PER_WL = 5;
    uint256 public MAX_PER_TX = 20;

    address[] private teamAddresses = [
        0x4fC06DF1232a9D044Fa49786880aa7D7A00d24Fd,
        0xDD9CE18a57AF9BF623d80DFd7c23A7589a604E6A
    ];

    uint256[] private teamShares = [50, 50];

    //  0: INACTIVE, 1: PRE_SALE, 2: PUBLIC_SALE
    uint256 public saleState = 0;

    bytes32 private merkleRoot;

    mapping(address => uint256) whitelistMints;

    Counters.Counter private idTracker;

    string public baseURI;

    constructor() ERC721("AngryBullSociety", "ABS") PaymentSplitter(teamAddresses, teamShares) {
        // Start id from 1
        idTracker.increment();
    }

    function totalSupply() public view returns (uint256) {
        return idTracker.current() - 1;
    }

    function mintInternal(address addr) internal {
        uint256 tokenId = idTracker.current();
        _mint(addr, tokenId);
        idTracker.increment();
    }

    /**
     * @notice  This function enables owner to mint without restriction
     * @param amount Amount of NFTs to be minted
     */
    function ownerMint(uint256 amount) external payable onlyOwner {
        require(msg.value >= amount * PUBLIC_SALE_PRICE, "ABS: Insufficient funds.");

        uint256 currentId = idTracker.current();
        require(currentId + amount <= MAX_SUPPLY, "ABS: Purchasable NFTs are all minted.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
    }

    /**
     * @notice  Mints NFTs purchasable in the pre-sale period.
     * @param amount Amount of NFTs attempted to be minted in the transaction.
     * @param merkleProof Merkle proof provided by the server to verify whether the sender is pre-sale whitelisted
     */
    function mintPreSale(uint256 amount, bytes32[] calldata merkleProof) external payable {
        require(saleState == 1, "ABS: Pre-sale has not started yet.");
        require(amount < MAX_PER_WL, "ABS: Amount exceeds pre-sale wallet cap.");
        require(msg.value >= amount * PRE_SALE_PRICE, "ABS: Insufficient funds.");

        uint256 currentId = idTracker.current();
        require(currentId + amount <= MAX_SUPPLY, "ABS: Purchasable NFTs are all minted.");

        require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender))),
            "ABS: Merkle verification has failed, address is not in the pre-sale whitelist.");

        require(whitelistMints[msg.sender] + amount < MAX_PER_WL,
            "ABS: Address has reached the wallet cap in pre-sale.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
        whitelistMints[msg.sender] += amount;
    }

    /**
     * @notice  Mints NFTs purchasable in the public sale period.
     * @param amount Amount of NFTs attempted to be minted in the transaction.
     */
    function mintPublicSale(uint256 amount) external payable {
        require(saleState == 2, "ABS: Public sale has not started yet.");
        require(amount <= MAX_PER_TX, "ABS: Amount exceeds transaction mint cap.");
        require(msg.value >= amount * PUBLIC_SALE_PRICE, "ABS: Insufficient funds.");

        uint256 currentId = idTracker.current();
        require(currentId + amount <= MAX_SUPPLY, "ABS: Purchasable NFTs are all minted.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
    }

    function _baseURI() internal view override (ERC721) returns (string memory) {
        return baseURI;
    }

    function setSaleState(uint256 _saleState) external onlyOwner {
        require(_saleState >= 0 && _saleState < 3, "ABS: Invalid new sale state.");
        saleState = _saleState;
    }

    function setPreSalePrice(uint256 preSalePrice) external onlyOwner {
        PRE_SALE_PRICE = preSalePrice;
    }

    function setPublicSalePrice(uint256 publicSalePrice) external onlyOwner {
        PUBLIC_SALE_PRICE = publicSalePrice;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }
}