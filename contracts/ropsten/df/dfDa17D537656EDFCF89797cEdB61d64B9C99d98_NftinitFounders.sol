// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract NftinitFounders is ERC721, Ownable, PaymentSplitter {
    using Counters for Counters.Counter;

    uint256 public MAX_SUPPLY = 120;

    uint256 public SALE_PRICE = 0.69 ether;

    uint256 public MAX_PER_WL = 5;
    uint256 public MAX_PER_TX = 10;

    address[] private teamAddresses = [
        0xE3EcD66ee10bE20a8FB61899a41B1805AD35D3Ec,
        0x7EbCAA5cE859De87D61af28D07676a035646eb00
    ];

    uint256[] private teamShares = [50, 50];

    //  0: INACTIVE, 1: PRE_SALE, 2: PUBLIC_SALE
    uint256 public SALE_STATE = 0;

    bytes32 private merkleRoot;

    mapping(address => uint256) whitelistMints;

    Counters.Counter private idTracker;

    string public baseURI;

    constructor() ERC721("NFTinit Founders", "NFTF") PaymentSplitter(teamAddresses, teamShares) {
        idTracker.increment();
    }

    function totalSupply() public view returns (uint256) {
        return idTracker.current() - 1;
    }

    function mintInternal(address addr) internal {
        _mint(addr, idTracker.current());
        idTracker.increment();
    }

    function ownerMint(uint256 amount) external payable onlyOwner {
        require(msg.value >= amount * SALE_PRICE, "NFTF: Insufficient funds.");
        require(idTracker.current() + amount <= MAX_SUPPLY, "NFTF: Purchasable NFTs are all minted.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
    }

    function mintPreSale(uint256 amount, bytes32[] calldata merkleProof) external payable {
        require(SALE_STATE == 1, "NFTF: Pre-sale has not started yet.");
        require(amount < MAX_PER_WL, "NFTF: Amount exceeds pre-sale wallet cap.");
        require(msg.value >= amount * SALE_PRICE, "NFTF: Insufficient funds.");
        require(idTracker.current() + amount <= MAX_SUPPLY, "NFTF: Purchasable NFTs are all minted.");

        require(MerkleProof.verify(merkleProof, merkleRoot, keccak256(abi.encodePacked(msg.sender))), "NFTF: Merkle verification has failed, address is not in the pre-sale whitelist.");

        require(whitelistMints[msg.sender] + amount < MAX_PER_WL, "NFTF: Address has reached the wallet cap in pre-sale.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
        whitelistMints[msg.sender] += amount;
    }

    function mintPublicSale(uint256 amount) external payable {
        require(SALE_STATE == 2, "NFTF: Public sale has not started yet.");
        require(amount <= MAX_PER_TX, "NFTF: Amount exceeds transaction mint cap.");
        require(msg.value >= amount * SALE_PRICE, "NFTF: Insufficient funds.");

        require(idTracker.current() + amount <= MAX_SUPPLY, "NFTF: Purchasable NFTs are all minted.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
    }

    function _baseURI() internal view override (ERC721) returns (string memory) {
        return baseURI;
    }

    function setSaleState(uint256 _saleState) external onlyOwner {
        require(_saleState >= 0 && _saleState < 3, "NFTF: Invalid new sale state.");
        SALE_STATE = _saleState;
    }

    function setSupply(uint256 _maxSupply) external onlyOwner {
        MAX_SUPPLY = _maxSupply;
    }

    function setSalePrice(uint256 _preSalePrice) external onlyOwner {
        SALE_PRICE = _preSalePrice;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }
}