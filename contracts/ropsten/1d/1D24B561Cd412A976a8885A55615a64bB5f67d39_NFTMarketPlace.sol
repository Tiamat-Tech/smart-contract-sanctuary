// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';


/**
 * @title NFT Market Place contract
 * @dev Main point of interaction with Swan bond protocol
 * - Create a bond token
 * - Add an Admin
 * - Issue a bond
 * - Add trusted conctract to exchange the bonds token
 * - Withdraw ERC20 token after bond have been purchase
 * - Buy bond token
 * @author Swan
 */

contract NFTMarketPlace is AccessControl {
  struct Offer {
    address payable seller;
    uint256 price;
    uint256 tokenId;
  }
  address public nftAddr;

  Offer[] offers;

  mapping (uint256 => Offer) tokenIdToOffer;
  mapping (uint256 => uint256) tokenIdToOfferId;

  event MarketTransaction(string TxType, address owner, uint256 tokenId);

  constructor(address _nftAddr){
    nftAddr = _nftAddr;
  }


  function getOffer(uint256 _tokenId)public view returns(address seller,uint256 price,uint256 tokenId) {
      Offer storage offer = tokenIdToOffer[_tokenId];
      return (offer.seller,offer.price,offer.tokenId);
  }

  function getAllTokenOnSale() public view returns(uint256[] memory listOfToken){
    uint256 totalOffers = offers.length;
    
    if (totalOffers == 0) {
        return new uint256[](0);
    } else {
      uint256[] memory resultOfToken = new uint256[](totalOffers);

      uint256 offerId;
  
      for (offerId = 0; offerId < totalOffers; offerId++) {
        if(offers[offerId].price != 0){
          resultOfToken[offerId] = offers[offerId].tokenId;
        }
      }
      return resultOfToken;
    }
  }

  function setOffer(uint256 _price, uint256 _tokenId) public{
      /*
      *   We give the contract the ability to transfer kitties
      *   As the kitties will be in the market place we need to be able to transfert them
      *   We are checking if the user is owning the kitty inside the approve function
      */
      require(tokenIdToOffer[_tokenId].price == 0, "You can't sell twice the same offers ");
      IERC1155 nft = IERC1155(nftAddr);
      require(nft.isApprovedForAll(msg.sender, address(this)) , "You can't sell twice the same offers ");

      Offer memory _offer = Offer({
        seller: payable(msg.sender),
        price: _price,
        tokenId: _tokenId
      });

      tokenIdToOffer[_tokenId] = _offer;

      offers.push(_offer);

      uint256 index = offers.length - 1;

      tokenIdToOfferId[_tokenId] = index;

      emit MarketTransaction("Create offer", msg.sender, _tokenId);
  }

  function removeOffer(uint256 _tokenId) public {
    //IERC1155 nft = IERC1155(nftAddr);
    
    //require(nft.balanceOf(msg.sender, _tokenId), "The user doesn't own the token");

    Offer memory offer = tokenIdToOffer[_tokenId];

    require(offer.seller == msg.sender, "You should own the kitty to be able to remove this offer");

    /* we delete the offer info */
    delete offers[tokenIdToOfferId[_tokenId]];

    /* Remove the offer in the mapping*/
    delete tokenIdToOffer[_tokenId];


    //_deleteApproval(_tokenId);

    emit MarketTransaction("Remove offer", msg.sender, _tokenId);
  }

  function buyNFT(uint256 _tokenId,uint256 _amt)public payable {

    Offer memory offer = tokenIdToOffer[_tokenId];
    require(msg.value == offer.price, "The price is not correct");

    /* we delete the offer info */
    delete offers[tokenIdToOfferId[_tokenId]];

    /* Remove the offer in the mapping*/
    delete tokenIdToOffer[_tokenId];

    IERC1155 nft = IERC1155(nftAddr);
    
    require(nft.isApprovedForAll(msg.sender, address(this)) , "You can't sell twice the same offers ");

    nft.safeTransferFrom(offer.seller, msg.sender, _tokenId,_amt,'');

    offer.seller.transfer(msg.value);
    emit MarketTransaction("Buy", msg.sender, _tokenId);
  }


}