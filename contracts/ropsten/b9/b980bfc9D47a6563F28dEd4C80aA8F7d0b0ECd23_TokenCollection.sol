// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./EnglishAuction.sol";
import "./DutchAuction.sol";
import "./IAuction.sol";

contract TokenCollection is ERC721 {
    
  address public owner;
  IAuction[6] public auctions;
  string public ipfsHash;
  uint private tokenCount;
  
  constructor() ERC721("Test1", "TEST") {
    owner = msg.sender;
    ipfsHash = "e.io";
    tokenCount = 1;
  }
  
  function setIpfsHash(string memory _ipfsHash) public {
    require(msg.sender == owner);
    ipfsHash = _ipfsHash;
  }
  
  function _baseURI() internal view virtual returns (string memory) {
    return ipfsHash;
  }
  
  function createEnglishAuction(uint tokenId, uint numWeeks, uint reserve) public {
    IAuction newAuction = new EnglishAuction(
      msg.sender, 
      ipfsHash, 
      numWeeks, 
      reserve
    );
    auctions[tokenId-1] = newAuction;
  }
  
  /*
  tokenId: count of NFT to be sold, numWeeks: duration of auction, price: start
  price in wei, priceDrop: how much price drops as auction progresses,
  dropInterval: how many days to drop the price
  */
  function createDutchAuction(
    uint tokenId, 
    uint numWeeks, 
    uint price, 
    uint priceDrop, 
    uint dropInterval
  ) public {
    IAuction newAuction = new DutchAuction(
      msg.sender, 
      ipfsHash, 
      numWeeks,
      price,
      priceDrop,
      dropInterval
    );
    auctions[tokenId-1] = newAuction;
  }
  
  function mint(address receiver) external {
    require(tokenCount < 7 && msg.sender == owner);
    super._safeMint(receiver, tokenCount);
    tokenCount++;
  }
  
  function transfer(uint256 tokenId) external {
    IAuction finishedAuction = auctions[tokenId-1];
    uint state = finishedAuction.getState();
    require(state != 0, "Auction can not still be active.");
    
    // cleanup and transfer NFT
    finishedAuction.finalise();
    if(finishedAuction.getState() == 2) {
      bytes memory data = "";
      super._safeTransfer(owner, finishedAuction.getWinner(), tokenId, data);
    }
  }
    
}