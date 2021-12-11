// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./INFTToken.sol";

contract NFTAuction is Ownable, ReentrancyGuard, IERC721Receiver{
    using SafeMath for uint256;

    INFTToken public token;
    uint256 public bidIncrementPercentage;
    address public constant charityAddress = 0x5b6898464A33AAc30Eca30a3D1482c40a6bd8884;
    
    struct Auction {
        address owner;
        // The minimum price accepted in an auction
        uint256 minNFTPrice;
        uint256 escrowAmount;
        uint256 start;
        uint256 end;
        bool canceled;
        address highestBidderAddress;
        uint256 highestBidAmount;
    }

    mapping(uint256 => mapping (address => uint256)) public bidder;
    // mapping of token ID to Auction Structure
    mapping (uint256 => Auction) public auction;

    event LogAuction(address creator, uint256 tokenID, uint256 startTime, uint256 endTime, bool status);
    event LogBid(uint256 tokenID, address bidder, uint256 amount);
    event LogWithdrawal(uint tokenID, address withdrawalAccount, uint256 amount);
    event LogAuctionWinner(uint tokenID, address winnerAddress);
    event LogCanceled(uint256 tokenID);   // modifier onlyOwner {

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }  

    constructor (address _token, uint256 _bidIncrementPercentage) {
        require(_token != address(0), "owner is zero address");
        require(_bidIncrementPercentage > 0, "Bid increament should be more then 0%");
        token = INFTToken(_token);
        bidIncrementPercentage = _bidIncrementPercentage; // for 5% => 500
    }

     uint256 public tokenID;

    function createAuction(uint256 _minNFTPrice, uint256 _start, uint256 _end) public onlyOwner {

        // mint NFT 
       
        if((token.totalSupply()+1).mod(5) == 0 && token.totalSupply() > 1){
            tokenID = token.mint(charityAddress);
            tokenID = token.totalSupply() - 1;
        } else {
            tokenID = token.mint(address(this));
            // Create NFT bid by contract owner
            auction[tokenID] = Auction({
                owner: msg.sender,
                minNFTPrice: _minNFTPrice,
                escrowAmount: 0,
                start: _start,
                end: _end,
                canceled: false,
                highestBidderAddress: address(0),
                highestBidAmount: 0
            });
        }
        emit LogAuction(msg.sender, tokenID, _start, _end, false);
       
    }

    function placeBid(uint256 _tokenID) public payable nonReentrant{
        Auction storage _auction = auction[_tokenID];
        
        require(block.timestamp >= _auction.start, "Auction not started yet");
        require(block.timestamp <= _auction.end, 'Auction expired');
        require(_auction.canceled == false, "Auction canceled");
        require(msg.sender != _auction.owner, "Owner cannot place bid");
        if(_auction.highestBidAmount > 0){
            uint256 amount =_auction.highestBidAmount;
            require(
                bidder[_tokenID][msg.sender].add(msg.value) >= amount.add((amount.mul(bidIncrementPercentage)).div(10000)),
                'Must send more than last bid by minBidIncrementPercentage amount'
            );
        } else{
            require(msg.value >= _auction.minNFTPrice, 'Must send at least minimum NFT price');
        }
       
        bidder[_tokenID][msg.sender] = bidder[_tokenID][msg.sender].add(msg.value);

        // uint256 _amount = bidder[_tokenID][msg.sender];
        // if(_amount > 0){
        //     payable(msg.sender).transfer(_amount);
        // } 
        // bidder[_tokenID][msg.sender] = msg.value;

        _auction.highestBidAmount = bidder[_tokenID][msg.sender];
        _auction.highestBidderAddress = msg.sender;

        _auction.escrowAmount = _auction.escrowAmount.add(msg.value);

        emit LogBid(_tokenID, msg.sender, bidder[_tokenID][msg.sender].add(msg.value));
    }

    function cancelAuction(uint _tokenID) public onlyOwner {
        Auction storage _auction = auction[_tokenID];
        require(_auction.end > block.timestamp, "Auction already completed");
        _auction.canceled = true;
        emit LogCanceled(_tokenID);
    }

    function claimNFT(uint256 _tokenID) public nonReentrant {
        Auction storage _auction = auction[_tokenID];
        require(_auction.end < block.timestamp, "Auction still under progress");
        uint256 amount = bidder[_tokenID][msg.sender];
        require(amount > 0, "You are not a bidder");
        require(_auction.highestBidderAddress == msg.sender, "You are not winner" );
        payable(_auction.owner).transfer(_auction.highestBidAmount);
            // Transfer NFT to contract
        token.safeTransferFrom(address(this), msg.sender, _tokenID);
        _auction.escrowAmount = _auction.escrowAmount.sub(amount);
        bidder[_tokenID][msg.sender] = 0;
        emit LogAuctionWinner(_tokenID, msg.sender);
    }

    function withdrawBid(uint256 _tokenID) public nonReentrant {
        Auction storage _auction = auction[_tokenID];
        require(_auction.end < block.timestamp || _auction.canceled, "Auction still under progress");
        require(_auction.highestBidderAddress != msg.sender, "You are winner so claim your NFT" );
        uint256 amount = bidder[_tokenID][msg.sender];
        require(_auction.escrowAmount >= amount, "Auction amount is less");
        payable(msg.sender).transfer(amount);
        _auction.escrowAmount = _auction.escrowAmount.sub(amount);
        bidder[_tokenID][msg.sender] = 0;
        emit LogWithdrawal(_tokenID, msg.sender, amount);
    }

    function withdrawDust(address _to, uint256 _amount) external onlyOwner{
        uint256 balance = address(this).balance;
        require(balance >= _amount, "Balance should atleast equal to amount");
        payable(_to).transfer(_amount);
    }
    
}