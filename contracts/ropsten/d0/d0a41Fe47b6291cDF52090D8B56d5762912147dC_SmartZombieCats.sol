// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./SmartZombieLab.sol";

/**
 * @title SmartZombieCats contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract SmartZombieCats is ERC721Enumerable, Ownable {

    uint public constant SMART_ZOMBIE_COUNT = 2550;
    
    SmartZombieLab private szl;

    using SafeMath for uint256;

    bool mintingIsActive = false;

    uint public maxCats;
    string public baseURI;

    struct Set {
        uint[] values;
        mapping (uint => bool) claimed;
    }

    Set claimedIds;

    constructor(uint _maxNftSupply, address _dependentContractAddress) ERC721("My Companion", "MYCO") {
        require(_maxNftSupply > 0, "_maxNftSupply was not given");
        
        require(_dependentContractAddress != address(0), "_dependentContractAddress was not given");

        maxCats = _maxNftSupply;
        szl = SmartZombieLab(_dependentContractAddress);
    }

    /*
    * Add the Smart Zombie ID to the Claimed Token Registry
    */
    function addClaimedId(uint szlTokenId) private {
        if (!claimedIds.claimed[szlTokenId]) {
            claimedIds.values.push(szlTokenId);
            claimedIds.claimed[szlTokenId] = true;
        }
    }

    /**
    * Check if the cat for a given SZL token ID has already been claimed
    */
    function isClaimed(uint256 szlTokenId) public view returns (bool) {
        require(szlTokenId < SMART_ZOMBIE_COUNT, "Requested szlTokenId exceeds upper limit");
        
        return claimedIds.claimed[szlTokenId];
    }
    
    /**
    * Set Base URI
    */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * Activate or deactivate minting
     */
    function activateMinting(bool active) public onlyOwner {
        if (active) {
            bytes memory tempString = bytes(baseURI);
            require(tempString.length != 0, "baseURI has not been set");
        }
        
        mintingIsActive = active;
    }

    /**
     * Close minting for good
    */
    function terminateMinting() public onlyOwner {
        maxCats = totalSupply(); // prevents more cats being minted
        
        if (mintingIsActive) {
            mintingIsActive = false;
        }
    }

    /**
    * Claim cat for a specific Smart Zombie token id. Minted ids will not be contiguous
    */
    function claimCat(uint256 szlTokenId) public {
        require(mintingIsActive, "Minting must be active to claim a cat");
        require(totalSupply() < maxCats, "Claim would exceed max supply of cats");
        require(isClaimed(szlTokenId) == false, "Cat has already been claimed for this Smart Zombie ID");
        require(szl.ownerOf(szlTokenId) == msg.sender, "Must own the Smart Zombie for requested tokenId to claim a cat");
        
        // claim the next available ID and mark the szlTokenId as being claimed
        // (does not track which cat ID was claimed by which zombie ID)
        uint supply = totalSupply();
        _safeMint(msg.sender, supply);
        addClaimedId(szlTokenId);
    }

    /**
     * Get the metadata for a given tokenId
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, Strings.toString(tokenId)))
            : "";
    }

    /**
     * Get current balance of contract (Owner only)
     */
    function getBalance() public view onlyOwner returns (uint)  {
        uint balance = address(this).balance;
        return balance;
    }

    /**
     * Withdraw all funds from contract (Owner only)
     * Cats are free to claim so there should be no funds!
     */
    function withdrawFunds() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}