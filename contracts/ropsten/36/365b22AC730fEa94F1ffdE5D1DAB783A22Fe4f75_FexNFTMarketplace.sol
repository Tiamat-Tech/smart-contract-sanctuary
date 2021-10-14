// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FexNFT.sol";
import "./FexPaymentGateway.sol";

contract FexNFTMarketplace is Ownable {

  FexNFT private _FexNFT;
  FexPaymentGateway private _FexPaymentGateway;
  address payable publisherWallet;

  struct Offer{
    address payable seller;
    address tokenAddress;
    uint256 price;
    uint256 offerId;
    uint256 tokenId;
    bool isSold;
    bool active;
  }

  Offer[] public offers;

  mapping(uint256 => Offer) tokenIdToOffer;

  event fexNFTAdded(address tokenAddress, address seller, uint256 price, uint256 tokenId, uint256 offerId, bool isSold);
  event fexNFTSold(address tokenAddress, address buyer, uint256 price, uint256 tokenId, uint256 offerId);
  event priceChanged(address owner, uint256 price, address tokenAddress, uint256 tokenId, uint256 offerId);
  event fexNFTRemoved(address owner, uint256 tokenId, address tokenAddress);

  constructor(address _FexNFTContractAddress, address _FexPaymentGatewayAddress, address payable _publisherWallet) {
    _setFexNFTContract(_FexNFTContractAddress);
    _setFexPaymentGatewayContract(_FexPaymentGatewayAddress);
    publisherWallet = _publisherWallet;
  }

  function _setFexPaymentGatewayContract(address _FexPaymentGatewayAddress) private onlyOwner{
    _FexPaymentGateway = FexPaymentGateway(_FexPaymentGatewayAddress);
  }

  function _setFexNFTContract(address _FexNFTContractAddress) private onlyOwner{
    _FexNFT = FexNFT(_FexNFTContractAddress);
  }

  function setOffer(uint256 price, uint256 tokenId, address tokenAddress) public{
    require(_FexNFT.ownerOf(tokenId) == msg.sender, "Only the owner of the fexNFT is allowed to do this");
    require(_FexNFT.isApprovedForAll(msg.sender, address(this)) == true, "Not approved to sell");
    require(price >= 1000, "Price must be greater than or equal to 1000 wei");
    require(tokenIdToOffer[tokenId].active == false, "Item is already on sale");

    uint256 offerId = offers.length;

    Offer memory offer = Offer(payable(msg.sender), tokenAddress, price, offerId, tokenId, false, true);

    tokenIdToOffer[tokenId] = offer;

    offers.push(offer);

    emit fexNFTAdded(address(_FexNFT), msg.sender, price, tokenId, offerId, false);
  }

  function changePrice(uint256 newPrice, uint256 tokenId, address tokenAddress) public{
    require(offers[tokenIdToOffer[tokenId].offerId].seller == msg.sender, "Must be seller");
    require(newPrice >= 1000, "Price must be greater than or equal to 1000 wei");
    require(offers[tokenIdToOffer[tokenId].offerId].active == true, "Offer must be active");
    require(offers[tokenIdToOffer[tokenId].offerId].isSold == false, "Item already sold");

    offers[tokenIdToOffer[tokenId].offerId].price = newPrice;

    emit priceChanged(msg.sender, newPrice, tokenAddress, tokenId, offers[tokenIdToOffer[tokenId].offerId].offerId);
  }

  function removeOffer(uint256 tokenId, address tokenAddress) public{
    require(offers[tokenIdToOffer[tokenId].offerId].seller == msg.sender, "Must be the seller/owner to remove an offer");

    offers[tokenIdToOffer[tokenId].offerId].active = false;
    delete tokenIdToOffer[tokenId];

    emit fexNFTRemoved(msg.sender, tokenId, tokenAddress);
  }

  function buyAsset(uint256 tokenId, address tokenAddress) public payable{
    Offer memory offer = tokenIdToOffer[tokenId];
    require(offers[offer.offerId].price == msg.value, "Payment must be equal to price of the asset");
    require(offers[offer.offerId].seller != msg.sender, "Cannot buy your own fexNFT");
    require(offers[offer.offerId].active == true, "Offer must be active");

    delete tokenIdToOffer[tokenId];
    offers[offer.offerId].isSold = true;
    offers[offer.offerId].active = false;

    _FexNFT.safeTransferFrom(offer.seller, msg.sender, tokenId);

    _distributeFees(tokenId, offers[offer.offerId].price, offer.seller);

    emit fexNFTSold(tokenAddress, msg.sender, offers[offer.offerId].price, offers[offer.offerId].tokenId, offers[offer.offerId].offerId);
  }

  function _computeCreatorFee(uint256 price, uint8 royalty) internal pure returns(uint256){
    uint256 creatorFee = price * royalty / 100;
    return creatorFee;
  }

  function _computePublisherFee(uint256 price) internal pure returns(uint256){
    uint256 publisherFee = price * 2 / 100;
    return publisherFee;
  }

  function _distributeFees(uint256 tokenId, uint256 price, address payable seller) internal{
    uint8 creatorRoyalty = _FexNFT.getRoyalty(tokenId);
    uint256 creatorFee = _computeCreatorFee(price, creatorRoyalty);
    uint256 publisherFee = _computePublisherFee(price);
    uint256 payment = price - creatorFee - publisherFee;

    address payable creator = _FexNFT.getCreator(tokenId);

    _FexPaymentGateway.sendPayment{value: creatorFee}(creator);
    _FexPaymentGateway.sendPayment{value: payment}(seller);
    _FexPaymentGateway.sendPayment{value: publisherFee}(publisherWallet);
  }
}