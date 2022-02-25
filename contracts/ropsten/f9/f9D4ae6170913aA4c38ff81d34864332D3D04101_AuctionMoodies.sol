// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract AuctionMoodies is IERC721Receiver {
  ERC721 nonFungibleContract;

  address nftAddress;

  event List(address indexed from, uint256 price, uint tokenId, uint256 timestamp);
  event Sale(address indexed from, address indexed to, uint256 price, uint tokenId, uint256 timestamp);

  struct AuctionStruct {
    uint256 id;
    address seller;
    uint128 price;
    uint256 timestamp;
  }

  mapping (uint256 => AuctionStruct) auctions;

  uint256 counter;

  constructor( address _nftAddress ) payable {
    nonFungibleContract = ERC721(_nftAddress);
    nftAddress = _nftAddress;
    counter = 0;
  }

  function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function create(uint256 _tokenId, uint128 _price ) public {
    uint256 timestamp = block.timestamp;
    AuctionStruct memory _auction = AuctionStruct({
      id: _tokenId,
      seller: msg.sender,
      price: uint128(_price),
      timestamp: timestamp
    });
    auctions[counter] = _auction;
    counter++;
    emit List(msg.sender, _price, _tokenId, timestamp);
  }

  function buy( uint256 _tokenId ) public payable {
    uint index = findTokenIndex(_tokenId);
    AuctionStruct memory auction = auctions[index];
    require(auction.seller != msg.sender, "Buyer should not be the owner.");
    require(msg.value >= auction.price);

    address seller = auction.seller;
    uint128 price = auction.price;

    delete auctions[index];
    counter--;

    payable(seller).transfer(price);
    nonFungibleContract.transferFrom(seller, msg.sender, _tokenId);

    emit Sale(seller, msg.sender, price, _tokenId, block.timestamp);
  }

  function cancel( uint256 _tokenId ) public {
    AuctionStruct memory auction = auctions[_tokenId];
    require(auction.seller == msg.sender);

    uint index = findTokenIndex(_tokenId);

    // remove from mapping
    delete auctions[index];
    counter--;
  }

  function findTokenIndex ( uint _tokenId ) public view returns (uint) {
    uint index = 0;
    for (uint i = 0; i < counter - 1; i++) {
      if (auctions[i].id == _tokenId) {
        index = i;
        break;
      }
    }

    return index;
  }

  function getAll() public view returns (AuctionStruct[] memory) {
    AuctionStruct[] memory ret = new AuctionStruct[](counter);
    if (counter == 0) return ret;

    for (uint i = 0; i < counter; i++) {
      ret[i] = auctions[i];
    }

    return ret;
  }
}