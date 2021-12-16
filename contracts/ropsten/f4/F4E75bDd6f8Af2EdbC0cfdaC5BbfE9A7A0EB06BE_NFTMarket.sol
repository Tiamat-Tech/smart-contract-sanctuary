// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFTMarket is ReentrancyGuard {

using Counters for Counters.Counter;
Counters.Counter private _itemIds;
Counters.Counter private _itemSold;

address payable owner;
uint256 listingPrice = 0.0025 ether;

constructor(){
    owner = payable(msg.sender);
}

struct MarketItem {
    uint ItemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
}

mapping(uint => MarketItem) private idToMarketItem;

event marketItemCreated
(
    uint itemId,
    address nftContract,
    uint256 tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
);

function getListingPrice() public view returns(uint256)
{
    return listingPrice;
}

function createMarketItem(address NFTcontract, uint256 tokenId, uint256 price) public payable nonReentrant
{
    require(price > 0, 'price must be atleast equal 1 wei');
    require(msg.value == listingPrice, 'price must be equal to listing price');

    _itemIds.increment();
    uint256 itemId = _itemIds.current();
    idToMarketItem[itemId] = MarketItem
    (
        itemId,
        NFTcontract,
        tokenId,
        payable(msg.sender),
        payable(address(0)),
        price,
        false
    );
    IERC721(NFTcontract).transferFrom(msg.sender, address(this), tokenId);     //ownership back to creater so when they sell gave ownership to another
 
    emit marketItemCreated(itemId, NFTcontract, tokenId, msg.sender, address(0), price, false);

}

function createMarketSale(address NFTContract, uint256 itemId) public payable nonReentrant
{
    uint256 price =  idToMarketItem[itemId].price;
    uint256 tokenId = idToMarketItem[itemId].tokenId;
    require(msg.value == price, 'please submit the asking price in order to complete the purchase');

    idToMarketItem[itemId].seller.transfer(msg.value);                // PAISE SELLER ko transfer kr raha jo khareede ga
    IERC721(NFTContract).transferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[itemId].owner = payable(msg.sender);               // whoever pay for nft he/she would be new own that nft in that map function in which owner is adress(0)
    idToMarketItem[itemId].sold = true;
    _itemSold.increment();
    payable(owner).transfer(listingPrice);                            // owner gets his listing fee

}

}