// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title Mr_Whisker's NFT Collection
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract MeowsDAO is ERC721, Ownable {
    using SafeMath for uint256;

    string public PROVENANCE = "";
    string public CONTRACT_METADATA_URI = "";
    bool public saleIsActive = false;
    uint256 public MAX_KITTENS;
    uint256 public startingIndexBlock;
    uint256 public startingIndex;
    uint256 public constant kittensPrice = 75000000000000000; // 0.075 ETH
    uint256 public constant maxKittenPurchase = 30;
    uint256 public REVEAL_TIMESTAMP;

    event KittenMinted(address indexed _to, uint256 indexed _tokenId);
    event Withdrawal(address indexed sender, uint256 amount);
    event ToggleSalesState(bool _saleIsActive);
    event SetBaseURI(string _baseURI);
    event StartingSequence(uint256 _startingIndex);

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxNftSupply,
        uint256 saleStart
    ) ERC721(name, symbol) {
        MAX_KITTENS = maxNftSupply;
        REVEAL_TIMESTAMP = saleStart + (86400 * 9);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
        emit Withdrawal(msg.sender, balance);
    }

    function reserveKittens() public onlyOwner {
        uint256 supply = totalSupply();
        uint256 i;
        for (i = 0; i < 250; i++) {
            _safeMint(msg.sender, supply + i);
            emit KittenMinted(msg.sender, supply + i);
        }
    }

    function setRevealTimestamp(uint256 revealTimeStamp) public onlyOwner {
        REVEAL_TIMESTAMP = revealTimeStamp;
    }

    /*
     * Set provenance once it's calculated
     */
    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        require(
            bytes(PROVENANCE).length != 0,
            "Provenance has already been set, no do-overs!"
        );
        PROVENANCE = provenanceHash;
    }

    /*
     *  Set contract metadata URI for OpenSea storefront-level
     *  https://docs.opensea.io/docs/contract-level-metadata
     */
    function setContractURI(string memory _contractMetadataURI)
        public
        onlyOwner
    {
        CONTRACT_METADATA_URI = _contractMetadataURI;
    }

    /*
     *  Get contract metadata for OpenSea
     */
    function contractURI() public view returns (string memory) {
        return CONTRACT_METADATA_URI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    /*
     * Pause sale if active, make active if paused
     */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
        emit ToggleSalesState(saleIsActive);
    }

    /**
     * Mints MeowDAO's Mr.Whisker's progeny
     */
    function mintLitter(uint256 numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Mr. Whiskers");
        require(
            numberOfTokens <= maxKittenPurchase,
            "Can only mint 20 tokens at a time"
        );
        require(
            totalSupply().add(numberOfTokens) <= MAX_KITTENS,
            "Purchase would exceed max supply of Mr. Whiskers"
        );
        require(
            kittensPrice.mul(numberOfTokens) <= msg.value,
            "Ether value sent is not correct"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            if (totalSupply() < MAX_KITTENS) {
                _safeMint(msg.sender, mintIndex);
            }
        }

        /*
            If we haven't set the starting index and this is either 
                1) the last saleable token or 
                2) the first token to be sold after
            the end of pre-sale, set the starting index block
        */
        if (
            startingIndexBlock == 0 &&
            (totalSupply() == MAX_KITTENS ||
                block.timestamp >= REVEAL_TIMESTAMP)
        ) {
            startingIndexBlock = block.number;
        }
    }

    /**
     * Set the starting index for the collection
     */
    function setStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint256(blockhash(startingIndexBlock)) % MAX_KITTENS;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint256(blockhash(block.number - 1)) % MAX_KITTENS;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */
    function emergencySetStartingIndexBlock() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        startingIndexBlock = block.number;
    }
}