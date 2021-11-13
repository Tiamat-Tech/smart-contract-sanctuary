// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "hardhat/console.sol";

enum OfferState{
  NULL,
  FULFILLED,
  OPEN,
  CLOSED
}

contract Market is ReentrancyGuard, Ownable {
  using Math for uint256;

  // get historical offers (historical sales)
  // get open offer for tokenId+collection  
  // get offers that are OPEN order by price 
  // get offers that are OPEN from a particular seller
  // fulfill an offer (buy) 
  // close an offer (delist)
  

  struct Offer {
    OfferState state;
    uint256 tokenId;
    uint256 price;
    uint256 offerId;
    address collection;
    address payable seller;
    address buyer;
    address currency;
  }

  using Counters for Counters.Counter;
  Counters.Counter private offerIds;
  Counters.Counter private offersFulfilled;

  mapping(uint256 => Offer) private offers;
  mapping(address => bool) private currencies;
  mapping(bytes32 => uint256) private offerIdByToken;

  event OfferOpen (
    uint256 indexed offerId,
    address indexed collection,
    uint256 indexed tokenId,
    address seller,
    uint256 price,
    address currency
  );
  
  event OfferClosed (
    uint256 indexed offerId,
    address indexed collection,
    uint256 indexed tokenId,
    address seller,
    uint256 price,
    address currency
  );

  event OfferFulfilled (
    uint256 indexed offerId,
    address indexed collection,
    uint256 indexed tokenId,
    address seller,
    address buyer,
    uint256 price,
    address currency
  );

  constructor(address[] memory _currs) {
    _whitelistCurrencies(_currs);
  }


  function _whitelistCurrencies(address[] memory _currencies) internal {
    for (uint i = 0; i < _currencies.length; i++) {
      currencies[_currencies[i]] = true;
    }
  }

  /* Places an item for sale on the marketplace */
  function openOffer(
    address _collection,
    uint256 _tokenId,
    uint256 _price,
    address _currency
  ) public payable nonReentrant {


    require(_price > 0, "Price must be more than 0");
    require(currencies[_currency], "Listing must be in whitelisted currency");
    require(IERC721(_collection).ownerOf(_tokenId) == msg.sender, "You cannot post a listing you do not own");

    offerIds.increment();
    uint256 _offerId = offerIds.current();
  
    offers[_offerId] = Offer(
      OfferState.OPEN,
      _tokenId,
      _price,
      _offerId,
      _collection,
      payable(msg.sender),
      address(0), // buyer is blank until sold
      _currency
    );
    
    offerIdByToken[keccak256(abi.encodePacked(_collection, _tokenId))] = _offerId;

    emit OfferOpen(
      _offerId,
      _collection,
      _tokenId,
      msg.sender,
      _price,
      _currency
    );

    IERC721(_collection).transferFrom(msg.sender, address(this), _tokenId);
  }

  function updateOffer(uint _offerId, uint256 _price, address _currency) public nonReentrant {
    require(offers[_offerId].seller == msg.sender, "Only sellers can update offers");
    require(offers[_offerId].offerId != 0, "Offer must have been created");
    require(offers[_offerId].state == OfferState.OPEN, "Item must be currently open");  
    require(currencies[_currency] == true, "Listing must be in whitelisted currency");
    require(_price > 0, "Price must be greater than 0");
    
    offers[_offerId].price = _price;
    offers[_offerId].currency = _currency;
  }

  function delistOffer(
    uint _offerId
  ) public nonReentrant {
    uint256 _tokenId = offers[_offerId].tokenId;
    address _collection = offers[_offerId].collection;
    address _seller = offers[_offerId].seller;
    uint256 _price = offers[_offerId].price;
    address _currency = offers[_offerId].currency;
    
    require(_seller == msg.sender, "Only sellers can delist offers");
    require(offers[_offerId].offerId != 0, "Offer must have been created");
    require(offers[_offerId].state == OfferState.OPEN, "Offer must be open");  
    
    offers[_offerId].state = OfferState.CLOSED;
    offerIdByToken[keccak256(abi.encodePacked(_collection, _tokenId))] = 0;
    offersFulfilled.increment();

    emit OfferClosed(
      _offerId,
      _collection,
      _tokenId,
      _seller,
      _price,
      _currency
    );

    IERC721(_collection).transferFrom(address(this), _seller, _tokenId);
  }

  /* Creates the sale of a marketplace item */
  /* Transfers ownership of the item, as well as funds between parties */
  function purchaseOffer (
    uint256 _offerId
    ) public payable nonReentrant {
    uint256 _price = offers[_offerId].price;
    address _collection = offers[_offerId].collection;
    uint256 _tokenId = offers[_offerId].tokenId;
    address _currency = offers[_offerId].currency;
    address _seller = offers[_offerId].seller;  

    // Add guard when enabling ETH
    require(msg.value == 0, "Do not allow ETH to be sent to this function call");
    require(offers[_offerId].offerId != 0, "Offer must have been created");
    require(offers[_offerId].state == OfferState.OPEN, "Offer must be open");  
    require(_seller != msg.sender, "You cannot buy the item off yourself");
    require(IERC20(_currency).balanceOf(msg.sender) > _price, "Buyer must have funds"); // Buyer has funds
    require(IERC721(_collection).ownerOf(_tokenId) == address(this), "The item must be owned by the market contract"); // Contract has NFT

    offerIdByToken[keccak256(abi.encodePacked(_collection, _tokenId))] = 0;
    offersFulfilled.increment();
    offers[_offerId].state = OfferState.FULFILLED;  

    emit OfferFulfilled(
      _offerId,
      _collection,
      _tokenId,
      _seller,
      msg.sender, // buyer
      _price,
      _currency
    );

    IERC20(_currency).transferFrom(msg.sender, _seller, _price);
    IERC721(_collection).transferFrom(address(this), msg.sender, _tokenId);
  }

  // get historical offers (historical sales)

  function getFulfilledOffersBySeller(address _seller, uint16 _perPage, uint16 _page) public view returns (Offer[] memory) {

  }

  function getFulfilledOffersByBuyer(address _buyer, uint16 _perPage, uint16 _page) public view returns (Offer[] memory) {

  }

  function getFulfilledOffersByToken(address _collection, uint256 _tokenId, uint16 _perPage, uint16 _page) public view returns (Offer[] memory) {

  }

  // get open offer for tokenId+collection  
  function getCurrentOpenOfferForToken(address _collection, uint256 _tokenId) public view returns (Offer memory) {
    uint256 _offerId = offerIdByToken[keccak256(abi.encodePacked(_collection, _tokenId))];
    return getOfferById(_offerId);
  }

  function getOfferById(uint256 _offerId) public view returns (Offer memory) {
    require(_offerId != 0, "No offer found for token.");
    require(offers[_offerId].offerId != 0 , "Offer must not be null");
    return offers[_offerId];
  }

  // get offers that are OPEN order by price 
  function getOpenOffersByRecent(
    address _collection, 
    uint16 _perPage, 
    uint16 _page // 0 indexed
  ) external view returns (Offer[] memory) {
    uint256 _offerCount = offerIds.current();
    uint256 _offersFulfilledCount = offersFulfilled.current();
    uint256 _openOfferCount = Math.min(_offerCount - _offersFulfilledCount, _perPage);
    uint256 _startId = _offerCount - (_perPage * _page);
    uint256 _currentIndex = 0;
    Offer[] memory _offers = new Offer[](_openOfferCount);
    for (uint256 _i = _startId; _i > 0; _i--) { 
      Offer memory _offer = offers[_i]; // offerId starts at 1
      if(_offer.state == OfferState.OPEN && _offer.collection == _collection){
        _offers[_currentIndex] = _offer;
        _currentIndex++;
      }
      if(_currentIndex >= _openOfferCount) break;
    }
    
    return _offers;
  }
  
  // get offers that are OPEN order by price 
  function getOpenOffersByPrice(address _collection, uint16 _perPage, uint16 _page) public view  returns (Offer[] memory) {
    // TBD
  }
  

  // get offers that are OPEN from a particular seller
  function getAllOpenOffersForSeller(
    address _seller, 
    uint16 _perPage, 
    uint16 _page
  ) public view  returns (Offer[] memory) {
    uint256 _offerCount = offerIds.current();
    uint256 _offersFulfilledCount = offersFulfilled.current();
    uint256 _openOfferCount = Math.min(_offerCount - _offersFulfilledCount, _perPage);
    uint256 _startId = _offerCount - (_perPage * _page);
    uint256 _currentIndex = 0;
    Offer[] memory _offers = new Offer[](_openOfferCount);
    console.log('cycling through all offers...');
    console.log('seller to filer for: ', _seller);
    for (uint256 _i = _startId; _i > 0; _i--) { 
      console.log('OFFER:', offers[_i].tokenId);
      console.log(' seller' , offers[_i].seller);
      console.log(' state' , uint(offers[_i].state));
      console.log(' tokenId' , offers[_i].tokenId);
      console.log(' collection' , offers[_i].collection);
      console.log(' price' , offers[_i].price);
      console.log(" OfferState.OPEN", offers[_i].state == OfferState.OPEN);
      console.log(" Seller is requested", offers[_i].seller == _seller);

      if(offers[_i].state == OfferState.OPEN && offers[_i].seller == _seller){
        _offers[_currentIndex] = offers[_i];
        _currentIndex++;
      }
      if(_currentIndex >= _openOfferCount) break;
    }
    
    return _offers;
  }
  // /* Returns all unsold market items */
  // /* rewrite this we should iterate outside of solidity or pass in limit */
  // function fetchOffersLatest(uint16 _limit/*, uint16 _page*/) public view returns (Offer[] memory) {
  //   uint _itemCount = offerIds.current();
  //   if(_limit == 0) _limit = 10;
  //   uint _unsoldItemCount = Math.min(offerIds.current() - offersFulfilled.current(), _limit);
  //   uint _currentIndex = 0;

  
  //   Offer[] memory _items = new Offer[](_unsoldItemCount);
    
  //   for (uint i = 0; i < _itemCount; i++) {
  //     Offer memory _item = offers[i + 1];
      
    
      
  //     if (!_item.sold ){
  //       _items[_currentIndex] = _item;
  //       _currentIndex += 1;
  //     }

  //    if(_currentIndex >= _unsoldItemCount) break;
  //   }
    
  //   return _items;
  // }

  // function fetchOfferId(address _collection, uint256 _tokenId) public view returns (uint256) {
  //   bytes32 _hash = keccak256(abi.encodePacked(_collection, _tokenId));
  //   uint256 _offerId = offerIdByToken[_hash];
  //   require(_offerId > 0, "Item must exist");
  //   return _offerId;
  // }

  // function fetchOffer(uint256 _offerId) public view returns (Offer memory){
  //   require(_offerId <= offerIds.current(), "ItemId must be valid");
  //   Offer memory _item = offers[_offerId];
  //   return _item;
  // }

}