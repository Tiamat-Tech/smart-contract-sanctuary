// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface NFTInterface {
  function safeTransferFrom(address from, address to, uint256 tokenId) external;
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

  uint128 public tax; 
  NFTInterface private nftInstance;
  EnumerableSet.UintSet private listedTokenIDs;
  mapping(uint256 => Listing) private listings;

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

    nftInstance.safeTransferFrom(msg.sender, address(this), _id);
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
  
    nftInstance.safeTransferFrom(
      address(this),
      msg.sender,
      _id
    );

    payable(sellerAddress).transfer(price.mul(100 - tax) / 100);
  }
  
  function changeListingPrice(uint256 _id, uint256 _newPrice) public isListed(_id) isSeller(_id) {
    listings[_id].price = _newPrice;
  }

  function cancelListing(uint256 _id) public isListed(_id) isSeller(_id) {
    delete listings[_id];
    listedTokenIDs.remove(_id);

    nftInstance.safeTransferFrom(address(this), msg.sender, _id);
  }

  function getListingIDs() public view returns (uint256[] memory) {
    EnumerableSet.UintSet storage set = listedTokenIDs;
    uint256[] memory tokens = new uint256[](set.length());

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i] = set.at(i);
    }
    return tokens;
  }

  function getNumberOfListingsBySeller(address _seller) public view returns (uint256) {
    EnumerableSet.UintSet storage listedTokens = listedTokenIDs;

    uint256 amount = 0;
    for (uint256 i = 0; i < listedTokens.length(); i++) {
      if (listings[listedTokens.at(i)].seller == _seller) 
        amount++;
    }

    return amount;
  }

  function getListingIDsBySeller(address _seller)
    public
    view
    returns (uint256[] memory tokens)
  {
    uint256 amount = getNumberOfListingsBySeller(_seller);
    tokens = new uint256[](amount);

    EnumerableSet.UintSet storage listedTokens = listedTokenIDs;

    uint256 index = 0;
    for (uint256 i = 0; i < listedTokens.length(); i++) {
      uint256 id = listedTokens.at(i);
      if (listings[id].seller == _seller)
        tokens[index++] = id;
    }

    return tokens;
  }

  /**
  * @dev Withdraws the balance of the contract to the senders address
  */
  function withdraw() public virtual onlyOwner {
    uint256 amount = address(this).balance;
    payable(msg.sender).transfer(amount);
  }
}