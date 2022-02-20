// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract AuctionMoodies is IERC721Receiver {
  ERC721 nonFungibleContract;

  address nftAddress;

  event List(address indexed from, uint256 price);
  event Sale(address indexed from, address indexed to, uint256 price);

  struct AuctionStruct {
    uint256 id;
    address seller;
    uint128 price;
  }

  mapping (uint256 => AuctionStruct) public tokenIdToAuction;
  uint auctionCount = 1;

  constructor( address _nftAddress ) payable {
    nonFungibleContract = ERC721(_nftAddress);
    nftAddress = _nftAddress;
  }

  function createAuction(uint256 _tokenId, uint128 _price ) public {
    nonFungibleContract.setApprovalForAll(msg.sender, true);
    AuctionStruct memory _auction = AuctionStruct({
      id: _tokenId,
      seller: msg.sender,
      price: uint128(_price)
    });
    tokenIdToAuction[_tokenId] = _auction;
    auctionCount++;
    emit List(msg.sender, _price);
  }

  function bid( uint256 _tokenId ) public payable {
    AuctionStruct memory auction = tokenIdToAuction[_tokenId];
    require(auction.seller != msg.sender, "Bidder should not be the owner.");
    require(msg.value >= auction.price);

    address seller = auction.seller;
    uint128 price = auction.price;

    delete tokenIdToAuction[_tokenId];
    auctionCount--;

    payable(seller).transfer(price);
    nonFungibleContract.transferFrom(seller, msg.sender, _tokenId);

    emit Sale(seller, msg.sender, price);
  }

  function cancel( uint256 _tokenId ) public {
    AuctionStruct memory auction = tokenIdToAuction[_tokenId];
    require(auction.seller == msg.sender);

    delete tokenIdToAuction[_tokenId];
    auctionCount--;
  }

  function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function getAll() public view returns (AuctionStruct[] memory){
      AuctionStruct[] memory auctions = new AuctionStruct[](auctionCount);
      for (uint i = 1; i < auctionCount; i++) {
        AuctionStruct memory auction = tokenIdToAuction[i];
        auctions[i] = auction;
      }
      return auctions;
  }
}