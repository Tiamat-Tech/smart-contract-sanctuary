//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "hardhat/console.sol";

interface NFTInterface {
  function ownerOf(uint256 tokenId) external returns (address);
  function approve(address to, uint256 tokenId) external;
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external;
}

contract Market is Context, Ownable {
  using EnumerableSet for EnumerableSet.UintSet;

  NFTInterface private nftContract;

  uint256 public addFee = 0.025 ether;
  uint256 public tax = 2; // 2%

  struct Listing {
    address payable owner;
    uint256 price;
  }

  mapping(uint256 => Listing) private listings;

  EnumerableSet.UintSet private listedTokenIDs;

  constructor() public {}

  modifier isListed(uint256 id) {
    require(listedTokenIDs.contains(id), "Token ID not listed");
    _;
  }

  modifier isNotListed(uint256 id) {
    require(!listedTokenIDs.contains(id), "Token ID must not be listed");
    _;
  }

  modifier isListingOwner(uint256 id) {
    require(listings[id].owner == msg.sender, "Access denied");
    _;
  }

  function setNftContractAddress(address _address) external onlyOwner {
    nftContract = NFTInterface(_address);
  }

  function setAddFee(uint256 _addFee) public virtual onlyOwner {
    addFee = _addFee;
  }

  function setTax(uint256 _tax) public virtual onlyOwner {
    tax = _tax;
  }

  function getListingIDs() public view returns (uint256[] memory) {
    uint256[] memory tokens = new uint256[](listedTokenIDs.length());

    for (uint256 i = 0; i < tokens.length; i++) {
      tokens[i] = listedTokenIDs.at(i);
    }
    return tokens;
  }

  function getListingPrice(uint256 _id) public view returns (uint256) {
    return listings[_id].price;
  }

  function addListing(uint256 _id, uint256 _price)
    public
    isNotListed(_id)
    isListingOwner(_id)
  {
    listings[_id] = Listing(msg.sender, _price);
    listedTokenIDs.add(_id);

    nftContract.approve(address(this), _id);
    nftContract.transferFrom(msg.sender, address(this), _id);
  }

  function changeListingPrice(uint256 _id, uint256 _newPrice)
    public
    isListed(_id)
    isListingOwner(_id)
  {
    listings[_id].price = _newPrice;
  }

  function cancelListing(uint256 _id) public isListed(_id) isListingOwner(_id) {
    delete listings[_id];
    listedTokenIDs.remove(_id);

    nftContract.transferFrom(address(this), msg.sender, _id);
  }

  function purchaseListing(uint256 _id) public payable isListed(_id) {
    Listing memory listing = listings[_id];
    require(msg.value >= listing.price, "Not enough funds sent");

    delete listings[_id];
    listedTokenIDs.remove(_id);

    payable(listing.owner).transfer(msg.value * (100 - tax) / 100);
    nftContract.transferFrom(address(this), msg.sender, _id);
  }

  function withdraw() public virtual onlyOwner {
    uint256 amount = address(this).balance;
    payable(msg.sender).transfer(amount);
  }
}