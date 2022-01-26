// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

/**
 * @title       Rebel Tiger Club Official NFT Smart Contract
 * @author      OPCODER - twitter.com/opcodereth
 * @notice      This contract is an ERC721 extension with added functionality for different minting scenarios.
 *  ______  ______  ______
 * /\  == \/\__  _\/\  ___\
 * \ \  __<\/_/\ \/\ \ \____
 *  \ \_\ \_\ \ \_\ \ \_____\
 *   \/_/ /_/  \/_/  \/_____/
 */
contract RebelTiger is ERC721, Ownable, PaymentSplitter {
    using Counters for Counters.Counter;

    // Supply related constants
    uint256 constant MAX_SUPPLY_SHIFTED = 51; // total number of purchasable tigers is 7777
    uint256 constant NUM_TIGERS_SHIFTED = 61; // total number of tigers is 8000 including gifts

    // Price related constants (owner settable)
    uint256 public PRE_SALE_PRICE = 0.066 ether;
    uint256 public PRIVATE_SALE_PRICE = 0.077 ether;
    uint256 public PUBLIC_SALE_PRICE = 0.088 ether;

    // Wallet caps and mint caps per transaction (owner settable)
    uint256 public WALLET_CAP_WL_SHIFTED = 6; // a whitelisted address can mint 5 NFTs at maximum in pre and private sales
    uint256 public MINT_CAP_TX_SHIFTED = 21; // one transaction can mint 20 NFTs at maximum in the public sale

    // Payment Splitter inputs TODO: Change to the actual address
    address[] private teamAddresses = [
        0x70DcC0995908eA307764e7a22B6C531e1926597A, // CTO
        0xDD9CE18a57AF9BF623d80DFd7c23A7589a604E6A, // CEO
        0x8f389F310797885209b3dd69708efade53cAb50e  // COO
    ]; 
    uint256[] private teamShares = [48, 48, 4]; // [CTO share, CEO share, COO share]

    // Sale States
    uint256 public saleState = 0; // { 0: INACTIVE, 1: PRE_SALE, 2: PRIVATE_SALE, 3: PUBLIC_SALE }

    // Merkle root for off-chain whitelist verifications
    bytes32 private merkleRootPreSale;
    bytes32 private merkleRootPrivateSale;

    // Mapping to store number of NFTs minted by a whitelist address
    mapping(address => uint256) whitelistMints;

    // Token ID tracker
    Counters.Counter private idTracker;

    // Base URI to prefix token URIs
    string public baseURI; 

    constructor() ERC721("RebelTiger", "RTC") PaymentSplitter(teamAddresses, teamShares) {
        idTracker.increment(); // Start the token ID from 1
    }

    // Total Supply
    function totalSupply() public view returns (uint256) {
        return idTracker.current() - 1;
    }

    // Minting functions
    function mintInternal(address addr) internal { // internal minting function to help refactoring code
        uint256 tokenId = idTracker.current();
        _mint(addr, tokenId);
        idTracker.increment();
    }

    /**
     * @notice  Mints NFTs purchasable in the pre-sale period.
     * @dev     Uses Merkle Tree verification to store whitelisted addresses off-chain hence reduce gas.
     * @param amount Amount of NFTs attempted to be minted in the transaction.
     * @param merkleProof Merkle proof provided by the server to verify whether the sender is pre-sale whitelisted.
     */
    function mintPreSale(uint256 amount, bytes32[] calldata merkleProof) external payable {
        require(saleState == 1, "RTC: Pre-sale has not started yet.");
        require(amount < WALLET_CAP_WL_SHIFTED, "RTC: Amount exceeds pre-sale wallet cap.");
        require(msg.value >= amount * PRE_SALE_PRICE, "RTC: Insufficient funds.");

        uint256 currentId = idTracker.current();
        require(currentId + amount - 1 < MAX_SUPPLY_SHIFTED, "RTC: Purchasable NFTs are all minted.");

        require(MerkleProof.verify(merkleProof, merkleRootPreSale, keccak256(abi.encodePacked(msg.sender))),
            "RTC: Merkle verification has failed, address is not in the pre-sale whitelist.");

        require(whitelistMints[msg.sender] + amount < WALLET_CAP_WL_SHIFTED,
            "RTC: Address has reached the wallet cap in pre-sale.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
        whitelistMints[msg.sender] += amount;
    }

    /**
     * @notice  Mints NFTs purchasable in the private sale period.
     * @dev     Uses Merkle Tree verification to store whitelisted addresses off-chain hence reduce gas.
     * @param amount Amount of NFTs attempted to be minted in the transaction.
     * @param merkleProof Merkle proof provided by the server to verify whether the sender is private sale whitelisted.
     */
    function mintPrivateSale(uint256 amount, bytes32[] calldata merkleProof) external payable {
        require(saleState == 2, "RTC: Private sale has not started yet.");
        require(amount < WALLET_CAP_WL_SHIFTED, "RTC: Amount exceeds private sale wallet cap.");
        require(msg.value >= amount * PRIVATE_SALE_PRICE, "RTC: Insufficient funds.");

        uint256 currentId = idTracker.current();
        require(currentId + amount - 1 < MAX_SUPPLY_SHIFTED, "RTC: Purchasable NFTs are all minted.");

        require(MerkleProof.verify(merkleProof, merkleRootPrivateSale, keccak256(abi.encodePacked(msg.sender))),
            "RTC: Merkle verification has failed, address is not in the private sale whitelist.");

        require(whitelistMints[msg.sender] + amount < WALLET_CAP_WL_SHIFTED,
            "RTC: Address has reached the wallet cap in private sale.");

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
        require(saleState == 3, "RTC: Public sale has not started yet.");
        require(amount < MINT_CAP_TX_SHIFTED, "RTC: Amount exceeds transaction mint cap.");
        require(msg.value >= amount * PUBLIC_SALE_PRICE, "RTC: Insufficient funds.");

        uint256 currentId = idTracker.current();
        require(currentId + amount - 1 < MAX_SUPPLY_SHIFTED, "RTC: Purchasable NFTs are all minted.");

        for (uint256 i = 0; i < amount; i++) {
            mintInternal(msg.sender);
        }
    }

    /**
     * @notice  Mints NFTs reserved as gifts for the community
     */
    function mintGifts() external onlyOwner {
        uint256 currentId = idTracker.current();
        require(currentId >= MAX_SUPPLY_SHIFTED, "RTC: Gift mints cannot start before sale is over.");

        for (uint256 i = currentId; i < NUM_TIGERS_SHIFTED; i++) {
            mintInternal(owner());
        }
    }

    // Only owner functions to set sale state
    function setSaleState(uint256 _saleState) external onlyOwner {
        require(_saleState >= 0 && _saleState < 4, "RTC: Invalid new sale state.");
        saleState = _saleState;
    }

    // Functions for the URI logic

    function _baseURI() internal view override (ERC721) returns (string memory) {
        return baseURI;
    }

    // Only owner setter functions

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function setMerkleRootPreSale(bytes32 _merkleRootPreSale) external onlyOwner {
        merkleRootPreSale = _merkleRootPreSale;
    }

    function setMerkleRootPrivateSale(bytes32 _merkleRootPrivateSale) external onlyOwner {
        merkleRootPrivateSale = _merkleRootPrivateSale;
    }

    function setPreSalePrice(uint256 preSalePrice) external onlyOwner {
        PRE_SALE_PRICE = preSalePrice;
    }

    function setPrivateSalePrice(uint256 privateSalePrice) external onlyOwner {
        PRIVATE_SALE_PRICE = privateSalePrice;
    }

    function setPublicSalePrice(uint256 publicSalePrice) external onlyOwner {
        PUBLIC_SALE_PRICE = publicSalePrice;
    }

    function setWalletCapWlShifted(uint256 walletCapWlShifted) external onlyOwner {
        WALLET_CAP_WL_SHIFTED = walletCapWlShifted;
    }

    function setMintCapTxShifted(uint256 mintCapTxShifted) external onlyOwner {
        MINT_CAP_TX_SHIFTED = mintCapTxShifted;
    }
}