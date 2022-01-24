// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "./nonceHandler.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Infynyty is ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable _owner;
  address private addressNonce;
  address private erc1155address;
  uint256 listingPrice = 0.025 ether;

  constructor(address addressNonceHandler) {
    _owner = payable(owner());
    addressNonce = addressNonceHandler;
  }

  struct Item {
    uint itemId;
    address nftAddress;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool itemSold;
  }
  struct ERC1155Sell{
    address seller;
    uint256 tokenId;
    address NFTAddress;
    uint256 nonce;
    uint256 listingPrice;
  }
  struct Sig {bytes32 r; bytes32 s; uint8 v;}

  mapping(uint256 => Item) private idItem;

  event EventItemCreated (
    uint indexed itemId,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool itemSold
  );

  // REVIEW: listing price disimpan di offchain
  // jadi kalau mau rubah harga bisa lebih fleksibel
  // sampai user merubah item ke status sale
  // konsepnya bisa ambil dari mekanime sale di opensea
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }
  
  function createERC721Item(address nftAddress, uint256 tokenId, uint256 price) public payable 
  {
    require(price > 0, "Price Invalid");
    require(msg.value == listingPrice, "Submitted price doesn't match with listing price.");
    _itemIds.increment();
    uint256 itemId = _itemIds.current();
    nonceHandler(addressNonce).setNonce(nftAddress, tokenId);
    idItem[itemId] =  Item(itemId, nftAddress, tokenId, payable(msg.sender), payable(address(0)), price, false);
    IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
    emit EventItemCreated(itemId, nftAddress, tokenId, msg.sender, address(0), price, false);
  }

  function createERC1155Item(ERC1155Sell memory nftInfo) public payable{
    _itemIds.increment();
    uint256 itemId = _itemIds.current();
    nonceHandler(addressNonce).setNonce(nftInfo.NFTAddress, nftInfo.tokenId);
    idItem[itemId] = Item(itemId, erc1155address, nftInfo.tokenId, payable(msg.sender), payable(address(0)), nftInfo.listingPrice, false);
    
  }

  function sellItem(address nftAddress, uint256 itemId) public payable {
    uint price = idItem[itemId].price;
    uint tokenId = idItem[itemId].tokenId;
    require(msg.value == price, "Price value is invalid.");
    idItem[itemId].seller.transfer(msg.value);
    IERC721(nftAddress).transferFrom(address(this), msg.sender, tokenId);
    idItem[itemId].owner = payable(msg.sender);
    idItem[itemId].itemSold = true;
    _itemsSold.increment();
    payable(_owner).transfer(listingPrice);
  }

  function fetchMarketItems() public view returns (Item[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    Item[] memory items = new Item[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
        //check if the item was sold or not
        if (idItem[i+1].owner == address(0)) {
            uint currentItemId = idItem[i+1].itemId;
            Item storage currentItem = idItem[currentItemId];
            items[currentIndex] = currentItem;
            currentIndex ++;
        }
    }
    return items;
  }

  function fetchMyNFTs() public view returns (Item[] memory) {
    uint itemCount = 0;
    uint index = 0;
    uint totalCount = _itemIds.current();

    for (uint256 i = 0; i < totalCount; i++) {
        //check if the item have the right owner
        if (idItem[i+1].owner == msg.sender) {
            itemCount ++;
        }
    }
    Item[] memory items = new Item[](itemCount);
    for (uint256 i = 0; i < totalCount; i++) {
      if (idItem[i+1].owner == msg.sender) {
        uint pointer = idItem[i+1].itemId;
        Item storage currentItem = idItem[pointer];
        items[index] = currentItem;
        index++;
      }
    }
    return items;
  }
  function itemOwned() public view returns (Item[] memory){
    uint itemCount = 0;
    uint index = 0;
    uint totalItem = _itemIds.current();

    for (uint256 i = 0; i < totalItem; i++) {
      if (idItem[i+1].seller == msg.sender) {
        itemCount ++;
      } 
    }
    Item[] memory items = new Item[] (itemCount);
    for (uint256 i = 0; i < totalItem; i++) {
      if (idItem[i + 1].seller == msg.sender) {
        uint pointer = idItem[i+1].itemId;
        Item storage item = idItem[pointer];
        items[pointer] = item;
        index ++;
      }
    }
    return items;
  }
  function verifySigner(address signer, bytes32 ethSignedMessageHash, Sig memory rsv) internal pure returns (bool)
  {
    return ECDSA.recover(ethSignedMessageHash, rsv.v, rsv.r, rsv.s ) == signer;
  }
  function messageHash(bytes memory abiEncode)internal pure returns (bytes32)
  {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abiEncode)));
  }  
}