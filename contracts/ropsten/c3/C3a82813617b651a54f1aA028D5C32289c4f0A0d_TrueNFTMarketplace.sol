//   ∙∙·▫▫ᵒᴼᵒ▫ₒₒ▫ᵒᴼⓉⓡⓤⓔ ⓃⒻⓉᴼᵒ▫ₒₒ▫ᵒᴼᵒ▫▫·∙∙
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TrueNFT.sol";
import "./PaymentGateway.sol";

contract TrueNFTMarketplace is Ownable {

  TrueNFT private _TrueNFT;
  PaymentGateway private _PaymentGateway;
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

  event trueAssetAdded(address tokenAddress, address seller, uint256 price, uint256 tokenId, uint256 offerId, bool isSold);
  event trueAssetSold(address tokenAddress, address buyer, uint256 price, uint256 tokenId, uint256 offerId);
  event priceChanged(address owner, uint256 price, address tokenAddress, uint256 tokenId, uint256 offerId);
  event trueAssetRemoved(address owner, uint256 tokenId, address tokenAddress);

  constructor(address _TrueNFTContractAddress, address _PaymentGatewayAddress, address payable _publisherWallet) {
    _setTrueNFTContract(_TrueNFTContractAddress);
    _setPaymentGatewayContract(_PaymentGatewayAddress);
    publisherWallet = _publisherWallet;
  }

  function _setPaymentGatewayContract(address _PaymentGatewayAddress) private onlyOwner{
    _PaymentGateway = PaymentGateway(_PaymentGatewayAddress);
  }

  function _setTrueNFTContract(address _TrueNFTContractAddress) private onlyOwner{
    _TrueNFT = TrueNFT(_TrueNFTContractAddress);
  }

  function setOffer(uint256 price, uint256 tokenId, address tokenAddress) public{
    require(_TrueNFT.ownerOf(tokenId) == msg.sender, "Only the owner of the trueAsset is allowed to do this");
    require(_TrueNFT.isApprovedForAll(msg.sender, address(this)) == true, "Not approved to sell");
    require(price >= 1000, "Price must be greater than or equal to 1000 wei");
    require(tokenIdToOffer[tokenId].active == false, "Item is already on sale");

    uint256 offerId = offers.length;

    Offer memory offer = Offer(payable(msg.sender), tokenAddress, price, offerId, tokenId, false, true);

    tokenIdToOffer[tokenId] = offer;

    offers.push(offer);

    emit trueAssetAdded(address(_TrueNFT), msg.sender, price, tokenId, offerId, false);
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

    emit trueAssetRemoved(msg.sender, tokenId, tokenAddress);
  }

  function buyAsset(uint256 tokenId, address tokenAddress) public payable{
    Offer memory offer = tokenIdToOffer[tokenId];
    require(offers[offer.offerId].price == msg.value, "Payment must be equal to price of the asset");
    require(offers[offer.offerId].seller != msg.sender, "Cannot buy your own trueAsset");
    require(offers[offer.offerId].active == true, "Offer must be active");

    delete tokenIdToOffer[tokenId];
    offers[offer.offerId].isSold = true;
    offers[offer.offerId].active = false;

    _TrueNFT.safeTransferFrom(offer.seller, msg.sender, tokenId);

    _distributeFees(tokenId, offers[offer.offerId].price, offer.seller);

    emit trueAssetSold(tokenAddress, msg.sender, offers[offer.offerId].price, offers[offer.offerId].tokenId, offers[offer.offerId].offerId);
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
    uint8 creatorRoyalty = _TrueNFT.getRoyalty(tokenId);
    uint256 creatorFee = _computeCreatorFee(price, creatorRoyalty);
    uint256 publisherFee = _computePublisherFee(price);
    uint256 payment = price - creatorFee - publisherFee;

    address payable creator = _TrueNFT.getCreator(tokenId);

    _PaymentGateway.sendPayment{value: creatorFee}(creator);
    _PaymentGateway.sendPayment{value: payment}(seller);
    _PaymentGateway.sendPayment{value: publisherFee}(publisherWallet);
  }
}