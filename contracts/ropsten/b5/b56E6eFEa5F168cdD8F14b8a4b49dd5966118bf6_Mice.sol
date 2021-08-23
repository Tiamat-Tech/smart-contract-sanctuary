// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './ERC721.sol';
import "./Ownable.sol";

/**
 * @title MiceHouse contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */


contract Mice is ERC721, Ownable {
    using SafeMath for uint256;

    uint256 public startingIndexBlock;
    uint256 public startingIndex;
    uint256 public mintPrice;
    uint256 public maxMintAmount;
    uint256 public MAX_MICE_SUPPLY;

    string public PROVENANCE_HASH = "";
    bool public saleIsActive;

    address wallet;

    constructor() ERC721("The Mice House", "TMH") {
        MAX_MICE_SUPPLY = 10000;
        mintPrice = 45000000000000000; // 0.045 ETH
        maxMintAmount = 25;
        saleIsActive = false;
        wallet = 0x8F859d32FD84bc0Da197c722d0C2e86Dcf95d950;
    }

    /**
     * Get the array of token for owner.
     */
    function tokensOfOwner(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    /**
     * Check if certain token id is exists.
     */
    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    /**
     * Set price to mint a Mice.
     */
    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    /**
     * Set maximum count to mint per once.
     */
    function setMaxToMint(uint256 _maxMintAmount) external onlyOwner {
        maxMintAmount = _maxMintAmount;
    }

    /*     
    * Set provenance once it's calculated
    */
    function setProvenanceHash(string memory _provenanceHash) external onlyOwner {
        PROVENANCE_HASH = _provenanceHash;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    /*
    * Pause sale if active, make active if paused
    */
    function setSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**
     * Mint Mices by owner
     */
    function reserveMices(address _to, uint256 _numberOfTokens) external onlyOwner {
        require(_to != address(0), "Invalid address to reserve.");
        uint256 supply = totalSupply();
        uint256 i;
        
        for (i = 0; i < _numberOfTokens; i++) {
            _safeMint(_to, supply + i);
        }
    }

    /**
    * Mints tokens
    */
    function mintMices(uint256 numberOfTokens) external payable {
        require(saleIsActive, "Sale must be active to mint");
        require(numberOfTokens <= maxMintAmount, "Invalid amount to mint per once");
        require(totalSupply().add(numberOfTokens) <= MAX_MICE_SUPPLY, "Purchase would exceed max supply");
        require(mintPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        
        for(uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            if (totalSupply() < MAX_MICE_SUPPLY) {
                _safeMint(msg.sender, mintIndex);
            }
        }

        // If we haven't set the starting index and this is first sold
        if (startingIndexBlock == 0) {
            startingIndexBlock = block.number;
        } 
    }

    /**
     * Set the starting index for the collection
     */
    function setStartingIndex() external {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        // Generate random number
        bytes32 hashOfRandom = keccak256(abi.encodePacked(startingIndexBlock, block.number, block.timestamp, block.difficulty));
        // Casts random number hash into uint256
        uint256 numberRepresentation = uint256(hashOfRandom);
        
        startingIndex = numberRepresentation% MAX_MICE_SUPPLY;

        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = block.number % MAX_MICE_SUPPLY;
        }

        if (startingIndex == 0) {
            startingIndex = 909;
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(wallet).transfer(balance);
    }
}