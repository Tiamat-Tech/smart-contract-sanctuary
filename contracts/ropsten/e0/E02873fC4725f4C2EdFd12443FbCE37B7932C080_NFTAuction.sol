// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./INFTToken.sol";

contract NFTAuction is Ownable{
    using SafeMath for uint256;

    INFTToken public token;
    uint256 public bidIncrementPercentage;
    
    struct Auction {
        address owner;
        // The minimum price accepted in an auction
        uint256 minNFTPrice;
        uint256 escrowAmount;
        uint256 start;
        uint256 end;
        bool canceled;
        address winnerAddress;
    }

    struct Bidder{
        address bidderAddr;
        uint256 amount;
    }

    // mapping of token ID to Auction Structure
    mapping (uint256 => Auction) public auction;

    // mapping of token ID to bidder address to bidder's fund
    // mapping (uint256 => mapping (address => uint256)) public fundsByBidder;
    mapping (uint256 => Bidder[]) public auctionBidder;

    event LogAuction(address creator, uint256 tokenID, uint256 startTime, uint256 endTime, bool status);
    event LogBid(uint256 tokenID, address bidder, uint256 amount);
    event LogWithdrawal(uint tokenID, address withdrawalAccount, uint256 amount);
    event LogAuctionWinner(uint tokenID, address winnerAddress);
    event LogCanceled(uint256 tokenID);   // modifier onlyOwner {

    constructor (address _token, uint256 _bidIncrementPercentage) {
        require(_token != address(0), "owner is zero address");
        // require(_minNFTPrice > 0);
        require(_bidIncrementPercentage > 0, "Bid increament should be more then 0%");
        token = INFTToken(_token);
        bidIncrementPercentage = _bidIncrementPercentage; // for 5% => 500
    }

    function createAuction(uint256 _minNFTPrice, uint256 _start, uint256 _end) public onlyOwner returns(uint256 tokenID){

        // mint NFT 
        uint256 _tokenId = token.mint();
     
        // Create NFT bid by contract owner
        auction[_tokenId] = Auction({
            owner: msg.sender,
            minNFTPrice: _minNFTPrice,
            escrowAmount: 0,
            start: _start,
            end: _end,
            canceled: false,
            winnerAddress: address(0)
        });

        emit LogAuction(msg.sender, _tokenId, _start, _end, false);
        return _tokenId;
    }

    function transferNFTToCharity(uint _tokenId, address charityAddress) public onlyOwner{
        cancelAuction(_tokenId);
        //Transfer NFT charity address 
        token.safeTransferFrom(address(this), charityAddress, _tokenId);
    }

    function highestBidAmountInAuction(uint256 _tokenId) internal view returns(address bidderAddr, uint256 amount){
        Bidder[] memory bidder = auctionBidder[_tokenId];
        uint256 _maxAmount;
        for(uint256 i = 0; i < bidder.length; i++){
            if(_maxAmount < bidder[i].amount){
                _maxAmount = bidder[i].amount;
                bidderAddr = bidder[i].bidderAddr;
            }
        } 
        return (bidderAddr, _maxAmount);
    }

     function findUserBidInAuction(uint256 _tokenID, address _bidderAddr) internal view returns(bool isBid, uint index, uint256 amount){
        Bidder[] memory bidder = auctionBidder[_tokenID];
        for(uint256 i = 0; i < bidder.length; i++){
            if(_bidderAddr == bidder[i].bidderAddr){
                return(true, i, bidder[i].amount);
            }
        } 
        return (false, 0, 0);
    }

    function placeBid(uint256 _tokenID) public payable{
        Auction memory _auction = auction[_tokenID];
        
        require(block.timestamp >= _auction.start, "Auction not started yet");
        require(block.timestamp <= _auction.end, 'Auction expired');
        require(msg.sender != _auction.owner, "Owner cannot place bid");
        require(msg.value >= _auction.minNFTPrice, 'Must send at least minimum NFT price');
        (, uint256 amount) = highestBidAmountInAuction(_tokenID);
        require(
            msg.value >= amount + ((amount * bidIncrementPercentage) / 10000),
            'Must send more than last bid by minBidIncrementPercentage amount'
        );

        (bool isBid, uint index, uint256 _amount) = findUserBidInAuction(_tokenID, msg.sender);
        if(isBid){
            payable(msg.sender).transfer(_amount);
            auctionBidder[_tokenID][index].amount = msg.value;
        } else{
            Bidder memory bidder;
            bidder.amount = msg.value;
            bidder.bidderAddr = payable(msg.sender);
            auctionBidder[_tokenID].push(bidder);
        }

        auction[_tokenID].escrowAmount = auction[_tokenID].escrowAmount.add(msg.value);

        emit LogBid(_tokenID, msg.sender, msg.value);
    }

    function cancelAuction(uint _tokenID) public onlyOwner returns (bool success) {
        Auction memory _auction = auction[_tokenID];
        require(_auction.end > block.timestamp, "Auction already completed");
        require(_auction.canceled == false, "Auction already canceled");

        auction[_tokenID].canceled = true;
        emit LogCanceled(_tokenID);
        return true;
    }

    function claim(uint256 _tokenID) public payable {
        Auction memory _auction = auction[_tokenID];
        require(_auction.end < block.timestamp, "Auction still under progress");
        (bool isBid, , uint256 amount) = findUserBidInAuction(_tokenID, msg.sender);
        require(isBid, "You are not a bidder");
        if(_auction.canceled){
            require(_auction.escrowAmount >= amount, "Aunction amount is less");
            payable(msg.sender).transfer(amount);
            emit LogWithdrawal(_tokenID, msg.sender, amount);
        } else {
            (address bidderAddr, uint256 _amount) = highestBidAmountInAuction(_tokenID);
            if(bidderAddr == msg.sender ){
                payable(_auction.owner).transfer(_amount);
                // Transfer NFT to contract
                token.safeTransferFrom(address(this), msg.sender, _tokenID);
                auction[_tokenID].winnerAddress = msg.sender;
                emit LogAuctionWinner(_tokenID, msg.sender);
            } else {
                require(_auction.escrowAmount >= amount, "Aunction amount is less");
                payable(msg.sender).transfer(amount);
                emit LogWithdrawal(_tokenID, msg.sender, amount);
            }
        }
    }
    
}