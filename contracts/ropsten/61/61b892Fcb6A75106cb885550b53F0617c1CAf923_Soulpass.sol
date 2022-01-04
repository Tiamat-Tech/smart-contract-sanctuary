// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface LootInterface {
    function ownerOf(uint) external view returns(address);
}

contract Soulpass is ERC721, Ownable {
    uint private mintTracker;
    uint private claimTracker;
    uint private burnTracker;

    string private _baseTokenURI;
    
    uint private constant maxMints = 3000;
    uint private constant maxClaims = 1000;
    uint private constant mintPrice = 60000000000000000;
    bool private paused = true;

    address lootAddress = 0xd733cd136522e1F18df3CaA3CA01Be71f9EDe24F; //This is the ropsten copy, mainnet loot has the address: 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
    LootInterface lootInterface = LootInterface(lootAddress);

    mapping(uint => bool) claimedLoots;
    mapping(address => bool) usedAdresses;

    constructor() ERC721("Soulpass", "SOUP") {
        _baseTokenURI = "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function mint() public payable {
        require(!paused || msg.sender == owner());
        require(msg.value == mintPrice || msg.sender == owner(), "It costs 0.03 eth to mint a Soulcast.");
        require(mintTracker < maxMints, "No more can be minted.");
        mintTracker++;
        _mint(msg.sender, mintTracker+claimTracker);
    }

    function claimLoot(uint lootID) public {
        require(!paused || msg.sender == owner(), "Minting has not yet started.");
        require(!claimedLoots[lootID], "This loot bag has already been used to claim.");
        require(!usedAdresses[msg.sender], "Only 1 claim per person.");
        require(claimTracker < maxClaims, "No more can be minted.");
        require(lootInterface.ownerOf(lootID) == msg.sender, "You do not own that loot bag!");
        mintTracker++;
        claimedLoots[lootID] = true;
        usedAdresses[msg.sender] = true;
        _mint(msg.sender, mintTracker+claimTracker);
    }

    function pauseUnpause(bool p) public onlyOwner {
        paused = p;
    }

    function totalSupply() public view returns(uint) {
        return mintTracker+claimTracker-burnTracker;
    }

    function totalMints() public view returns(uint) {
        return mintTracker;
    }

    function totalClaims() public view returns(uint) {
        return claimTracker;
    }

    function burn(uint tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");
        burnTracker++;
        _burn(tokenId);
    }

    function isClaimed(uint lootID) public view returns(bool) {
        return claimedLoots[lootID];
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}