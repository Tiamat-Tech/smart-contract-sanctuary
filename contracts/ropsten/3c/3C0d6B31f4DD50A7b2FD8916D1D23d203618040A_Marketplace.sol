//// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";

contract Marketplace {
    
    struct Trade {
        address poster;
        uint256 tokenId;
        IERC721 tokenContract;
        uint256 price;
        bytes32 status; // Open, Executed, Cancelled
    }
    struct Auction {
        address poster;
        uint256 tokenId;
        IERC721 tokenContract;
        uint256 price;
        bytes32 status;
        uint256 offerCount;
    }
    struct Offer {
        address poster;
        uint256 price;
        bytes32 status;
    }

    uint public tradeCounter;
    uint public auctionCounter;
    mapping(uint256 => Trade) public trades;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Offer[]) public Offers;
    mapping(uint256 => Offer[]) public freeOffers;
    mapping(uint256 => uint256) public freeOfferCount;
    
    
    
    constructor () {
        tradeCounter = 0;
    }

    function openTrade(address _tokenAddress, uint256 _tokenId, uint256 _price) public {

        IERC721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        trades[tradeCounter] = Trade({
            poster: msg.sender,
            tokenId: _tokenId,
            tokenContract: IERC721(_tokenAddress),
            price: _price,
            status: "Open"
        });

        tradeCounter++;
    }
    
    function openAuction(address _tokenAddress, uint256 _tokenId, uint256 _price) public {

        IERC721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        auctions[auctionCounter] = Auction({
            poster: msg.sender,
            tokenId: _tokenId,
            tokenContract: IERC721(_tokenAddress),
            price: _price,
            status: "Open",
            offerCount: 0
        });

        auctionCounter++;
    }

    function executeTrade(uint256 _trade) public payable tradeExists(_trade) {
        
        Trade memory trade = trades[_trade];
        require(trade.status == "Open", "Trade is not Open.");
        require(msg.value >= trade.price, "Did not pay enough.");
        payable(trade.poster).call{value: trade.price}("");
        trade.tokenContract.transferFrom(address(this), msg.sender, trade.tokenId);
        trades[_trade].status = "Executed";
        
        //emit TradeStatusChange(_trade, "Executed");
    }
    function makeOffer(uint256 _price,uint256 _tokenId) public payable{
        Offer memory _offer = Offer({
            poster: msg.sender,
            price: _price,
            status: "Open"
        });
        require(msg.value>=_offer.price, "not enough Ether");
        payable(address(this)).call{value: _offer.price}("");
        freeOffers[_tokenId][freeOfferCount[_tokenId]]=_offer;
        freeOfferCount[_tokenId]++;
    }

    function cancelFreeOffer(uint256 _tokenId, uint256 _offer) public payable{
        Offer memory offer = freeOffers[_tokenId][_offer];
        require(msg.sender==offer.poster," Offer can only be cancelled by poster");
        require(offer.status == "Open", "Offer is not Open");
        payable(offer.poster).call{value: offer.price}("");
        freeOffers[_tokenId][_offer].status="Cancelled";
    }

    function makeAuctionOffer(uint256 _auction, uint256 _price) public payable auctionExists(_auction){
        Offer memory _offer = Offer({
            poster: msg.sender,
            price: _price,
            status: "Open"
        });
        Auction memory auction = auctions[_auction];

        require(auction.status == "Open", "Auction is not Open.");
        require(msg.value>=_offer.price, "not enough Ether");
        require(msg.value > auctions[_auction].price, " new bid should be more");

        if(auction.offerCount>=1){
              payable(  Offers[_auction][auction.offerCount-1].poster).call{value: Offers[_auction][auction.offerCount-1].price}("");
        }
        console.log("here");
        console.log(auction.offerCount);
        payable(address(this)).call{value: _offer.price}("");
        Offers[_auction].push(_offer); 
        auctions[_auction].price = _price;
        auctions[_auction].offerCount++;
    
      
    }
    
    function acceptAuctionOffer(address _tokenAddress, uint256 _tokenId, uint256 _offer) public payable{
        Offer memory offer = Offers[_tokenId][_offer];
        require(msg.sender == IERC721(_tokenAddress).ownerOf(_tokenId), "You cant accept an offer, for an auction you dont host");
        require(offer.status =="Open", "Offer must be open");
        payable(msg.sender).call{value: offer.price}("");
        IERC721(_tokenAddress).transferFrom(address(this), offer.poster, _tokenId);
        freeOffers[_tokenId][_offer].status="Executed";
    }

    function acceptAuctionOffer(uint256 _auction, uint256 _offer) public payable auctionExists(_auction){
        Auction memory auction = auctions[_auction];
        Offer memory offer = Offers[_auction][_offer];
        require(msg.sender == auctions[_auction].poster, "You cant accept an offer, for an auction you dont host");
        require(offer.status =="Open", "Offer must be open");
        payable(auction.poster).call{value: offer.price}("");
        auction.tokenContract.transferFrom(address(this), offer.poster, auction.tokenId);
        Offers[_auction][_offer].status="Executed";
        for(uint i = 0; i<auction.offerCount;i++){
            if(Offers[_auction][i].status=="Open"){
                cancelAuctionOffer(_auction,i);
            }
        }
        auctions[_auction].status = "Executed";
    }
    
    function cancelAuctionOffer(uint256 _auction, uint256 _offer) public payable auctionExists(_auction){
        Offer memory offer = Offers[_auction][_offer];
        require(msg.sender==offer.poster," Offer can only be cancelled by poster");
        require(offer.status == "Open", "Offer is not Open");
        payable(offer.poster).call{value: offer.price}("");
        Offers[_auction][_offer].status="Cancelled";
    }
    
    function cancelAuction(uint256 _auction) public payable auctionExists(_auction){
        Auction memory auction = auctions[_auction];
        require(msg.sender == auction.poster, "Auction can be cancelled only by poster.");
        require(auction.status == "Open", "Auction is not Open.");
        auction.tokenContract.transferFrom(address(this), auction.poster,auction.tokenId);
        auctions[_auction].status="Cancelled";
        for(uint i = 0; i<auction.offerCount;i++){
            if(Offers[_auction][i].status=="Open"){
                cancelAuctionOffer(_auction,i);
            }
        }
    }
    
    function cancelTrade(uint256 _trade) public  tradeExists(_trade) {

        Trade memory trade = trades[_trade];
        require(msg.sender == trade.poster, "Trade can be cancelled only by poster.");
        require(trade.status == "Open", "Trade is not Open.");
        trade.tokenContract.transferFrom(address(this), trade.poster, trade.tokenId);
        trades[_trade].status = "Cancelled";
        //emit TradeStatusChange(_trade, "Cancelled");

    }
    
     
    
    //----------------------------------------------------------------------------------
    // modifiers
    
    modifier tradeExists(uint256 _trade) {
        require(_trade < tradeCounter, "trade does not exist");
        _;
    }
    modifier auctionExists(uint256 _auction) {
        require(_auction < auctionCounter, "auction does not exist");
        _;
    }
}