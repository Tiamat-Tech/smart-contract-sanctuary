// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./collectionNFT.sol";
import "./Ownable.sol";

contract SecondaryMarketplace is Ownable{

    collectionNFT public token;

    struct Offer {
        address offerer;
        uint256 price;
        bool isAccepted;
    }

    // Store all active sell offers  and maps them to their respective token ids
    mapping(uint256 => Offer) public activeOffers;

    event NewOffer(uint256 indexed tokenId, address indexed offerer, uint256 price);
    event OfferAccepted(uint256 indexed tokenID);
    event OfferReceived(uint256 indexed tokenID, address indexed buyer, uint256 price);

    function initialize(address _token) public onlyOwner{
        require(_token != address(0), "Invalid Address");
        token = collectionNFT(_token);
    }

    function createOffer(uint256 _tokenId, uint256 _price) public 
    {
        (,,uint256 price, bool isAuction) = token.tokenIdtoData(_tokenId);      
        require(!isAuction, "token is not available for direct sale");
        // require(_price * _amount < price * _amount, "offer must be less than fixed price");
        require(_price < price, "not enough ETH to buy");
        // Create sell offer
        activeOffers[_tokenId] = Offer({offerer : msg.sender, price : _price, isAccepted: false});
        // Broadcast sell offer
        emit NewOffer(_tokenId, msg.sender, price);
    }

    function acceptOffer(uint256 _tokenID) public onlyOwner {
        activeOffers[_tokenID].isAccepted = true;
        emit OfferAccepted(_tokenID);
    }

    function offerRecieve(uint256 _tokenID) public payable {
        require(activeOffers[_tokenID].isAccepted, "Offer is not accepted");
        require(msg.sender == activeOffers[_tokenID].offerer,"You are not offerer");
        require(msg.value >= activeOffers[_tokenID].price,"Not enough ETH to buy");
        token.mint(1, _tokenID);
        emit OfferReceived(_tokenID, msg.sender, msg.value);
    } 
}