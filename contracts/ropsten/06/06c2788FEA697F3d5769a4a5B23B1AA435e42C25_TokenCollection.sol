// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./EnglishAuction.sol";
import "./DutchAuction.sol";
import "./IAuction.sol";

contract TokenCollection is ERC721 {
    
  address public owner;
  IAuction[6] public auctions;
  uint private tokenCount;
  
  constructor() ERC721("Test2", "TEST") {
    owner = msg.sender;
    tokenCount = 1;
  }

  function mint(string memory tokenURI) external {
    require(tokenCount < 7 && msg.sender == owner);
    super._safeMint(owner, tokenCount);
    super._setTokenURI(tokenCount, tokenURI);
    tokenCount++;
  }
  
  function createEnglishAuction(uint tokenId, uint numWeeks, uint reserve) public {
    IAuction newAuction = new EnglishAuction(msg.sender, numWeeks, reserve);
    auctions[tokenId-1] = newAuction;
  }
  
  /*
  tokenId: count of NFT to be sold, numWeeks: duration of auction, price: start
  price in wei, priceDrop: how much price drops as auction progresses,
  dropInterval: how many days to drop the price
  */
  function createDutchAuction(
    uint tokenId, uint numWeeks, uint price, uint priceDrop, uint dropInterval
  ) public {
    IAuction newAuction = new DutchAuction(
      msg.sender, numWeeks, price, priceDrop, dropInterval
    );
    auctions[tokenId-1] = newAuction;
  }
  
  function transfer(uint256 tokenId) external {
    require(msg.sender == owner); // Consider removing this condition
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