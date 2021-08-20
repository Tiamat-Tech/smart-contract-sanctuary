// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IAuction.sol";
import "./DutchAuction.sol";

/*
Contract that implements the ERC721 standard to host a NFT collection, with 
functionality for minting and conducting full auctions of such NFTs.
*/
contract Collection is ERC721 {
    
  address public owner;
  IAuction[6] public auctions;
  uint private tokenCount;
  
  constructor() ERC721("Blake0", "BTST") {
    owner = msg.sender;
    tokenCount = 1;
  }
  
  // Creates a Dutch auction of the NFT at 'tokenId' with correct parameters
  // TODO: Ensure only the owner of that token is able to instantiate an auction
  function createDutchAuction(
    uint tokenId, 
    uint numWeeks, 
    uint price, 
    uint priceDrop, 
    uint dropInterval
  ) public {
    IAuction newAuction = new DutchAuction(
      payable(msg.sender), 
      numWeeks,
      price,
      priceDrop,
      dropInterval
    );
    auctions[tokenId-1] = newAuction;
  }
  
  // Functionality allowing owner to mint NFTs
  function mint(string memory tokenURI) external {
    require(msg.sender == owner);
    require(tokenCount < 7);
    super._safeMint(owner, tokenCount);
    super._setTokenURI(tokenCount, tokenURI);
    tokenCount++;
  }
  
  // Where public can bid for NFT. This ensures that the price is correct and
  // auction is in a correct state
  function dutchBid(uint tokenId) payable external {
    require(msg.sender != owner);
    IAuction selectedAuction = auctions[tokenId-1];
    require(selectedAuction.getState() == 0, "Auction no longer active.");
    
    uint256 currentPrice = selectedAuction.getCurrentPrice();
    require(msg.value >= currentPrice, "Bid has not met current price.");
    require(
      msg.value <= currentPrice + 50000000000000000,
      "Bid too high! Atleast 0.05 ETH over current price."
    );
    
    selectedAuction.setWinner(msg.sender);
    selectedAuction.getOwner().transfer(msg.value);
    selectedAuction.setState(2);
  }
  
  // Function called by frontend if 'dutchBid' has been correctly processed.
  // Transfers the NFT to the person who bought it 
  function moveft(uint tokenId) external {
    IAuction finishedAuction = auctions[tokenId-1];
    uint state = finishedAuction.getState();
    require(state != 0, "Auction can not still be active (or must exist!)");
    require(state != 3, "This NFT transfer has already been completed.");
    
    // cleanup and transfer NFT from auction owner to auction winner
    address _from = finishedAuction.getOwner();
    address _to = finishedAuction.getWinner();
    if(state == 2) {
      finishedAuction.finalise();
      bytes memory data = "";
      super._safeTransfer(_from, _to, tokenId, data);
    }
  }
    
}