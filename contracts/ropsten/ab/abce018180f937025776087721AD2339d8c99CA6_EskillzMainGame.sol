// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './EskillzToken.sol';

contract EskillzMainGame is Ownable {
    
    EskillzToken eskillzToken;
    uint8 public fee;
    string private _name;
     string private _symbol;
    mapping (uint => uint) tokenPrices;
    struct sellOffer {
        uint time;
        address from;
        uint256 amount;
        uint256 price;
    }
    sellOffer[] sellOffers;
    mapping(address => sellOffer[]) mySellOffers;

    event LogDepositMade(address accountAddress, uint amount);

    constructor() { 
        fee = 1;//1%
        _name = "EskillzMainGame";
        _symbol = "eskillzMainGame";
    }
    
    function setFee(uint8 _fee) 
        public onlyOwner 
    {
        fee = _fee;
    }

    function setPrice(uint tokenId, uint tokenPrice)
        public onlyOwner
    {
        tokenPrices[tokenId] = tokenPrice;
    }  

    function getPrice(uint tokenId)
        public view
        returns(uint)
    {
        require(eskillzToken.ownerOf(tokenId) == msg.sender);
        return tokenPrices[tokenId];
    }

    function transferToken(address from, address to, uint tokenId) 
        public 
    {
        require(from == msg.sender||owner()==msg.sender);
        eskillzToken.safeTransferFrom(from, to, tokenId);
    }

    function approveToken(address to, uint tokenId) 
        public 
    {
        require(eskillzToken.ownerOf(tokenId) == msg.sender||owner()==msg.sender);
        eskillzToken.approve(to, tokenId);
    }

    function createSellOffer(uint256 _amount, uint256 _price) 
        public 
    {
        sellOffer memory offer;
        offer.time = block.timestamp;
        offer.from = msg.sender;
        offer.amount = _amount;
        offer.price = _price;
        eskillzToken.transferFrom(msg.sender, address(this), _amount);
        //mySellOffers[msg.sender].push(sellOffers.push(offer));
    }

    function getAllSellOffersCount() 
        public view 
        returns (uint) 
    {
        return sellOffers.length;
    }

    function getMySellOffersCount() 
        public view 
        returns (uint) 
    {
        return mySellOffers[msg.sender].length;
    }

    function getSellOffer(uint index) 
        public view 
        returns (uint time, address from, uint256 amount, uint256 price) 
    {
        sellOffer memory offer = sellOffers[index];
        return (offer.time, offer.from, offer.amount, offer.price);
    }

    function buy(uint index) 
        public payable 
    {
        sellOffer memory offer = sellOffers[index];
        uint256 sum = offer.amount * offer.price;
        uint256 feeAmount = sum * fee / 100;
        require(msg.value < sum + feeAmount);
        //uint256 back = msg.value - (sum + feeAmount);
        emit LogDepositMade(msg.sender, offer.amount);   
        
    }

    function cancel(uint index) 
        public 
    {
        sellOffer memory offer = sellOffers[index];
        if (offer.from == msg.sender || msg.sender == owner()) {
            emit LogDepositMade(offer.from, offer.amount);
            deleteSellOffer(index);                
        }
    }

    function deleteSellOffer(uint index) 
        private 
    {
        uint length = sellOffers.length;
        if (length > 1) {
            sellOffers[index] = sellOffers[length - 1];
        }
    }

    function deposit() 
        public payable 
    {        
        emit LogDepositMade(msg.sender, msg.value); // fire event
    }

    function withdraw(uint amount) 
        public payable 
        onlyOwner 
        returns(bool) 
    {
        require(amount <= address(this).balance);
        payable(owner()).transfer(amount);
        return true;
    }

    function getOwnedTokenList(address recip)
        public view
        returns(uint256[] memory)
    {
        return eskillzToken.owendTokenList(recip);
    }

    function _transferOwnership(address recipient)
        public onlyOwner
    {      
        transferOwnership(recipient);
    } 

    function _ownerOfContract() 
        public view 
        returns(address)
    {      
        return owner();
    }

}