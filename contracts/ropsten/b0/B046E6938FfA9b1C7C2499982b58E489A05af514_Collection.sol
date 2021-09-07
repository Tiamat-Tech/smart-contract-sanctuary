// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IAuction.sol";
import "./DutchAuction.sol";
import "./EnglishAuction.sol";

/*
Contract that implements the ERC721 standard to host a NFT collection, with 
functionality for minting and conducting full auctions of such NFTs.
*/
contract Collection is ERC721 {
    
  address public owner;
  IAuction[6] public auctions;
  uint private tokenCount;

  uint public bidIncrement;
  uint private reserve;
  
  constructor() ERC721("Blake1", "BTST") {
    owner = msg.sender;
    tokenCount = 1;
    bidIncrement = 10000000000000000;
  }

  // Functionality allowing owner to mint NFTs
  function mint(string memory tokenURI) external {
    require(msg.sender == owner);
    require(tokenCount < 7);
    super._safeMint(owner, tokenCount);
    super._setTokenURI(tokenCount, tokenURI);
    tokenCount++;
  }  
  
  // Creates a Dutch auction of the NFT at 'tokenId' with correct parameters
  // TODO: Ensure only the owner of that token is able to instantiate an auction
  function createDutchAuction(
    uint tokenId, uint numWeeks, uint price, uint priceDrop, uint dropInterval
  ) public {
    IAuction newAuction = new DutchAuction(
      payable(msg.sender), numWeeks, price, priceDrop, dropInterval
    );
    auctions[tokenId-1] = newAuction;
  }

  // Creates an English auction of the NFT at 'tokenId' with correct parameters
  // TODO: Ensure only the owner of that token is able to instantiate an auction
  function createEnglishAuction(
    uint tokenId, uint numWeeks, uint _reserve
  ) public {
    IAuction newAuction = new EnglishAuction(
      payable(msg.sender), numWeeks, _reserve
    );
    reserve = _reserve;
    auctions[tokenId-1] = newAuction;
  }

  // Cancels the auction at 'tokenId'
  function cancelAuction(uint tokenId) external {
    auctions[tokenId-1].cancel();
  }
  
  // Where public can bid for NFT. This ensures that the price is correct and
  // auction is in a correct state
  function dutchBid(uint tokenId) payable external {
    require(msg.sender != owner);
    IAuction thisAuction = auctions[tokenId-1];
    require(thisAuction.getState() == 0, "Auction no longer active.");
    
    uint currentPrice = thisAuction.getCurrentPrice();
    require(msg.value >= currentPrice, "Bid has not met current price.");
    require(
      msg.value <= currentPrice + 50000000000000000,
      "Bid too high! Atleast 0.05 ETH over current price."
    );
    
    thisAuction.setWinner(payable(msg.sender));
    thisAuction.getOwner().transfer(msg.value);
    thisAuction.finalise();
  }

  // Where public can bid for NFT. This ensures that the price is correct and
  // auction is in a correct state. Also that overwritten bids are returned
  function englishBid(uint tokenId) payable external {
    IAuction thisAuction = auctions[tokenId-1];
    require(msg.sender != thisAuction.getOwner());
    require(thisAuction.getState() == 0, "Auction no longer active.");
    require(msg.value > thisAuction.getCurrentPrice() + bidIncrement);
    
    // repay previous highest bidder if not first bid
    if(thisAuction.getWinner() != address(0)) {
      thisAuction.getWinner().transfer(thisAuction.getCurrentPrice());
    }
    
    thisAuction.setWinner(payable(msg.sender));
    thisAuction.setCurrentPrice(msg.value);
  }
  
  // Auction owner needs to finalise an English auction when it is complete.
  // This completes the transfer of funds and prepares for the NFT move
  function englishFinalise(uint tokenId) external {
    IAuction thisAuction = auctions[tokenId-1];
    address payable thisOwner = thisAuction.getOwner();
    require(msg.sender == thisOwner || msg.sender == owner);
    
    // if the auction has been successful, complete transfer. Else cancel it
    // and refund the bid that was too low
    uint256 currentBid = thisAuction.getCurrentPrice();
    if(thisAuction.getCurrentPrice() >= reserve) {
      thisOwner.transfer(currentBid);
      thisAuction.finalise();
    } else {
      thisAuction.getWinner().transfer(currentBid);
      thisAuction.cancel();
    }
  }
  
  // Function called by frontend if 'dutchBid' has been correctly processed.
  // Transfers the NFT to the person who bought it 
  function moveft(uint tokenId) external {
    IAuction finishedAuction = auctions[tokenId-1];
    uint state = finishedAuction.getState();
    require(state == 2, "Auction must be resolved but not flushed.");
    
    // cleanup and transfer NFT from auction owner to auction winner
    address _from = finishedAuction.getOwner();
    address _to = finishedAuction.getWinner();
    if(state == 2) {
      finishedAuction.flush();
      bytes memory data = "";
      super._safeTransfer(_from, _to, tokenId, data);
    }
  }
    
}