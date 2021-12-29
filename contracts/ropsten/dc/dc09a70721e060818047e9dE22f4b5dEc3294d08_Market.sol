// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface NFTInterface {
  function transferFrom(address from, address to, uint256 tokenId) external;
  function ownerOf(uint256 tokenId) external returns (address);
  function getApproved(uint256 tokenId) external returns (address);
}

contract Market is Ownable {
  using EnumerableSet for EnumerableSet.UintSet;
  using SafeMath for uint256;

  struct Listing {
    address seller;
    uint256 price;
  }

  uint128 public tax = 2;  
  NFTInterface public nftInstance;
  EnumerableSet.UintSet private listedTokenIDs;
  mapping(uint256 => Listing) private listings;

  event NewListing(
    address indexed seller,
    uint256 indexed nftID,
    uint256 price
  );
  event ListingPriceChange(
    address indexed seller,
    uint256 indexed nftID,
    uint256 newPrice
  );
  
  event CancelledListing(
    address indexed seller,
    uint256 indexed nftID
  );

  event PurchasedListing(
    address indexed buyer,
    address seller,
    uint256 indexed nftID,
    uint256 price
  );

  modifier isListed(uint256 id) {
    require(
      listedTokenIDs.contains(id),
      "Token ID not listed"
    );
    _;
  }

  modifier isNotListed(uint256 id) {
    require(
      !listedTokenIDs.contains(id),
      "Token ID must not be listed"
    );
    _;
  }

  modifier isSeller(uint256 id) {
    require(
      listings[id].seller == msg.sender,
      "Access denied"
    );
    _;
  }

  modifier isApprover(uint256 id) {
    require(
      nftInstance.getApproved(id) == address(this),
      "Market not approver"
    );
    _;
  }

  modifier isOwnerItem(uint256 id){
    require(nftInstance.ownerOf(id) == msg.sender, "Sender does not own the item");
    _;
  }

  constructor(address _nftInstanceAddress) public {
    nftInstance = NFTInterface(_nftInstanceAddress);
  }

  function setNFTInstance(address _nftInstanceAddress) public onlyOwner {
    nftInstance = NFTInterface(_nftInstanceAddress);
  }

  function setTax(uint128 _newTax) public onlyOwner {
    tax = _newTax;
  }

  function addListing(uint256 _id, uint256 _price) public isOwnerItem(_id) isNotListed(_id) isApprover(_id)  {
    listings[_id] = Listing(msg.sender, _price);
    listedTokenIDs.add(_id);

    nftInstance.transferFrom(msg.sender, address(this), _id);
    
    emit NewListing(msg.sender, _id, _price);
  }
  
  function purchaseListing(uint256 _id) public payable isListed(_id) {
    address sellerAddress = listings[_id].seller;
    uint256 price = listings[_id].price;
  
    require(
      msg.value >= price,
      "Not enough money"
    );

    delete listings[_id];
    listedTokenIDs.remove(_id);
  
    nftInstance.transferFrom(
      address(this),
      msg.sender,
      _id
    );

    payable(sellerAddress).transfer(price.mul(100 - tax).div(100));

    emit PurchasedListing(msg.sender, sellerAddress, _id, price);
  }
  
  function changeListingPrice(uint256 _id, uint256 _newPrice) public isListed(_id) isSeller(_id) {
    listings[_id].price = _newPrice;

    emit ListingPriceChange(msg.sender, _id, _newPrice);
  }

  function cancelListing(uint256 _id) public isListed(_id) isSeller(_id) {
    delete listings[_id];
    listedTokenIDs.remove(_id);

    nftInstance.transferFrom(address(this), msg.sender, _id);

    emit CancelledListing(msg.sender, _id);
  }

  function getListings() public view returns (uint256[] memory, uint256[] memory, address[] memory) {
    EnumerableSet.UintSet storage set = listedTokenIDs;
    uint256[] memory ids = new uint256[](set.length());
    uint256[] memory prices = new uint256[](set.length());
    address[] memory seller = new address[](set.length());

    for (uint256 i = 0; i < ids.length; i++) {
      ids[i] = set.at(i);
      prices[i] = listings[set.at(i)].price;
      seller[i] = listings[set.at(i)].seller;
    }

    return (ids, prices, seller);
  }

  /**
  * @dev Withdraws the balance of the contract to the senders address
  */
  function withdraw() public virtual onlyOwner {
    uint256 amount = address(this).balance;
    payable(msg.sender).transfer(amount);
  }
}