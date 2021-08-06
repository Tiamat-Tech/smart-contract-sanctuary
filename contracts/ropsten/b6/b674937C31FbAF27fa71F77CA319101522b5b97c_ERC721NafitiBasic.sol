// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NafitiAuction {

    enum AuctionType{
        None,
        Timed,
        Free
    }


    enum AuctionStatus{
        None,
        Open,
        Cancelled,
        Completed
    }

    event AuctionCreated(address seller, AuctionType auctionType, address collectible, uint256 tokenId, uint256 amount);
    event BidPlaced(address bidder, uint256 tokenId, address collectible);
    event BidClosed(address highestBidder, uint256 highestBid, address seller);

    struct Bid {
        address payable highestBidder;
        uint256 highestBid;
        AuctionStatus auctionStatus;
        uint256 duration;
        address payable seller;
        uint256 quantity;
        AuctionType auctionType;
    }

    //Maps collectible address to user's address. 
    //And maps the address of the user to the tokens                                 
    mapping (address => mapping(uint256 => Bid)) auctions;

    IERC20 erc20TokenContract;


    constructor(address erc20TokenAddress) public
    {
        erc20TokenContract = IERC20(erc20TokenAddress);
    }


    function CreateAuctionForSingle(address _collectible, uint256 _tokenId, AuctionType _auctionType, uint256 _duration, uint256 _startingPrice) public payable
    {
        //Check that the seller is the owner of the collectible
        IERC721 erc721Contract = IERC721(_collectible);
        address ownerOfToken = erc721Contract.ownerOf(_tokenId);

        //Require Tha token actually belongs to the seller
        require(msg.sender == ownerOfToken, "Only token owner can auction");

        //Require that the auction is not currently open
        require(auctions[_collectible][_tokenId].auctionStatus != AuctionStatus.Open);

        Bid memory bid = Bid(msg.sender, _startingPrice, AuctionStatus.Open, _duration, msg.sender, 1, _auctionType);
        AuctionCreated(msg.sender, _auctionType, _collectible, _tokenId, _startingPrice);
    }

    function PlaceBid(address _collectible, uint256 _tokenId, uint _amount) public
    { 
        Bid storage bid = auctions[_collectible][_tokenId];

        //Require that the auction is not currently open
        require(auctions[_collectible][_tokenId].auctionStatus == AuctionStatus.Open);

        //Require that the bid to be placed is higher than the highest bid placed 
        require(auctions[_collectible][_tokenId].highestBid < _amount, "Bidding amount must be higher than the current highest bid");

        //Transfer the tokens to the Contract
        erc20TokenContract.transferFrom(msg.sender, address(this), _amount);

        //Transfer the previous Bidder's money back
        erc20TokenContract.transferFrom(address(this), bid.highestBidder, bid.highestBid);

        //Update the Bid 
        bid.highestBid = _amount;
        bid.highestBidder = msg.sender;
        BidPlaced(msg.sender, _tokenId, _collectible);
    }

    function CloseBid(address _collectible, uint256 _tokenId) public
    {
        Bid storage bid = auctions[_collectible][_tokenId];
        require(msg.sender == bid.seller, "Only Seller Can close the bid");
        require(bid.auctionType == AuctionType.Free, "Only fixed Bids can be bought");

        //Transfer the money to the seller
        erc20TokenContract.transferFrom(address(this), bid.seller, bid.highestBid);

        IERC721 erc721Contract = IERC721(_collectible);
        erc721Contract.safeTransferFrom(bid.seller, bid.highestBidder, _tokenId);
        BidClosed(bid.highestBidder, bid.highestBid, bid.seller);
    }

}