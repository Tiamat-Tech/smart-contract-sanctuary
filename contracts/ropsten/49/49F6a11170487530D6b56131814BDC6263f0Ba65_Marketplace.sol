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

     struct Royalty {
        address poster;
        uint256 amount;
        address royaltyAddress;
    }
    struct Auction {
        address poster;
        uint256 tokenId;
        IERC721 tokenContract;
        uint256 price;
        bytes32 status;
        uint256 offerCount;
        uint256  endtime;

    }
    struct Offer {
        address poster;
        uint256 price;
        IERC721 tokenContract;
        bytes32 status;
    }

      struct Bid {
        address poster;
        uint256 price;
    }

    uint public tradeCounter;
    uint public auctionCounter;
    address public feeAddress;

    mapping(uint256 => Trade) public trades;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionsBids;
    mapping(uint256 => Offer[]) public offers;
    mapping(uint256 => uint256) public offerCount;
    mapping(uint256 => Royalty) public NFTRoyalty;
    
    constructor () {
        tradeCounter = 0;
    }


    function setRoyalty(uint256 _tokenId,uint256 royalty,address _royaltyAddress ) public  {
        NFTRoyalty[_tokenId] = Royalty({
            poster: msg.sender,
            amount: royalty,
            royaltyAddress:_royaltyAddress
        });
        // TODO : for test  purpose ,to change Later 
        feeAddress = 0xcC118DdeA8A32B04b314126C4151A1875A3CfEb2;
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

        emit tradeListed(tradeCounter - 1, _tokenAddress, _tokenId, _price, msg.sender);       
    }
    
    function openAuction(address _tokenAddress, uint256 _tokenId, uint256 _price,uint256 _endtime) public {

        IERC721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        auctions[auctionCounter] = Auction({
            poster: msg.sender,
            tokenId: _tokenId,
            tokenContract: IERC721(_tokenAddress),
            price: _price,
            status: "Open",
            offerCount: 0,
            endtime:_endtime
        });

        auctionCounter++;

        emit auctionStarted(auctionCounter - 1, _tokenAddress, _tokenId, _price, _endtime, msg.sender);
    }

    function executeTrade(uint256 _trade) public payable tradeExists(_trade) {


        
        Trade memory trade = trades[_trade];
        Royalty memory royalty = NFTRoyalty[trade.tokenId];
        require(trade.status == "Open", "Trade is not Open.");
        require(msg.value >= trade.price, "Did not pay enough.");

       
        // our fees
        uint256 marketFee =   (trade.price * 150 / 10000 );

        console.log("trade.price",trade.price);
        console.log("market Fee",marketFee);
        uint256 shareprice = trade.price - marketFee;
        console.log("share price",shareprice);


        payable(feeAddress).call{value: marketFee }("");




       // royalty 
        payable(royalty.royaltyAddress).call{value: shareprice* royalty.amount / 10000 }("");

 


        // saler amount
        payable(trade.poster).call{value: shareprice * (10000 -royalty.amount)  / 10000 }("");

     
        trade.tokenContract.transferFrom(address(this), msg.sender, trade.tokenId);
        trades[_trade].status = "Executed";
        
        emit tradeExecuted(_trade, address(trade.tokenContract), trade.tokenId, msg.sender);
    }
    function makeOffer(uint256 _price,uint256 _tokenId, address _tokenAddress) public payable{
        Offer memory _offer = Offer({
            poster: msg.sender,
            tokenContract: IERC721(_tokenAddress),
            price: _price,
            status: "Open"
        });
        require(msg.value>=_offer.price, "not enough Ether");
        payable(address(this)).call{value: _offer.price}("");
        offers[_tokenId][offerCount[_tokenId]]=_offer;
        offerCount[_tokenId]++;
        emit offerMade(offerCount[_tokenId] - 1, _tokenAddress, _tokenId, _price, msg.sender);
    }

    function cancelOffer(uint256 _tokenId, uint256 _offer) public payable{
        Offer memory offer = offers[_tokenId][_offer];
        require(msg.sender==offer.poster," Offer can only be cancelled by poster");
        require(offer.status == "Open", "Offer is not Open");
        payable(offer.poster).call{value: offer.price}("");
        offers[_tokenId][_offer].status="Cancelled";
        emit offerCancled(_offer, address(offer.tokenContract), _tokenId);
    }

    function makeAuctionBid(uint256 _auction, uint256 _price) public payable auctionExists(_auction){
        Bid memory _bid = Bid({
            poster: msg.sender,
            price: _price
        });
        Auction memory auction = auctions[_auction];

        require( block.timestamp < auctions[_auction].endtime,"auction is finish" );
        require(auction.status == "Open", "Auction is not Open.");
        require(msg.value>=_bid.price, "not enough Ether");
        require(msg.value > auctions[_auction].price, " new bid should be more");

        if(auction.offerCount>=1){
              payable(  auctionsBids[_auction][auction.offerCount-1].poster).call{value: auctionsBids[_auction][auction.offerCount-1].price}("");
        }
       
        payable(address(this)).call{value: _bid.price}("");
        auctionsBids[_auction].push(_bid); 
        auctions[_auction].price = _price;
        auctions[_auction].offerCount++;
    
      emit auctionBid(_auction, address(auction.tokenContract), auction.tokenId, _price, msg.sender);
    }
    
    function acceptOffer(address _tokenAddress, uint256 _tokenId, uint256 _offer) public payable{
        Offer memory offer = offers[_tokenId][_offer];
        require(msg.sender == IERC721(_tokenAddress).ownerOf(_tokenId), "You cant accept an offer, for an auction you dont host");
        require(offer.status =="Open", "Offer must be open");
        payable(msg.sender).call{value: offer.price}("");
        IERC721(_tokenAddress).transferFrom(address(this), offer.poster, _tokenId);
        offers[_tokenId][_offer].status="Executed";

        emit offerAccepted(_offer, _tokenAddress, _tokenId, offer.price, offer.poster);
    }

    /// Should  maybe delete

    function acceptAuctionOffer(uint256 _auction, uint256 _bid) public payable auctionExists(_auction){
        Auction memory auction = auctions[_auction];
        Bid memory bid = auctionsBids[_auction][_bid];
        require(msg.sender == auctions[_auction].poster, "You cant accept an offer, for an auction you dont host");
       // require(bid.status =="Open", "Offer must be open");
        payable(auction.poster).call{value: bid.price}("");
        auction.tokenContract.transferFrom(address(this), bid.poster, auction.tokenId);
       // auctionsBids[_auction][_bid].status="Executed";
       // for(uint i = 0; i<auction.offerCount;i++){
           // if(auctionsBids[_auction][i].status=="Open"){
         //       cancelAuctionOffer(_auction,i);
           // }
       // }
       // auctions[_auction].status = "Executed";
    }
    
    /// Should delete maybe
    
    function cancelAuction(uint256 _auction) public payable auctionExists(_auction){
        Auction memory auction = auctions[_auction];
        require(msg.sender == auction.poster, "Auction can be cancelled only by poster.");
        require(auction.status == "Open", "Auction is not Open.");
        auction.tokenContract.transferFrom(address(this), auction.poster,auction.tokenId);
        auctions[_auction].status="Cancelled";
        uint maxBid = 0;
        uint maxBidder = 0;
        for(uint i = 0; i<auction.offerCount;i++){
            if(auctionsBids[_auction][i].price > maxBid){
                maxBidder = i;
            }
        }
        payable(  auctionsBids[_auction][maxBidder].poster).call{value: auctionsBids[_auction][maxBidder].price}("");
    }
    
    function cancelTrade(uint256 _trade) public  tradeExists(_trade) {

        Trade memory trade = trades[_trade];
        require(msg.sender == trade.poster, "Trade can be cancelled only by poster.");
        require(trade.status == "Open", "Trade is not Open.");
        trade.tokenContract.transferFrom(address(this), trade.poster, trade.tokenId);
        trades[_trade].status = "Cancelled";
        
        emit tradeCancled(_trade, address(trade.tokenContract), trade.tokenId);
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

    //----------------------------------------------------------------------------------
    // get Methods

    /*
    function getTrade(uint256 _trade) external view tradeExists(_trade) returns(Trade memory) {
        string[] memory trade;
        trade.push(trades)
    }
    */

    //----------------------------------------------------------------------------------
    // events

    event tradeListed(uint256 indexed tradeId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, address from);

    event tradeExecuted(uint256 indexed tradeId, address indexed _tokenAddress, uint256 indexed _tokenId, address to);

    event tradeCancled(uint256 indexed tradeId, address indexed _tokenAddress, uint256 indexed _tokenId);

    event auctionStarted(uint256 indexed auctionId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, uint256 _endtime, address from);

    event auctionBid(uint256 indexed auctionId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, address by);

    event auctionEnd(uint256 indexed auctionId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, address to);

    event offerMade(uint256 indexed offerId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, address by);

    event offerAccepted(uint256 indexed offerId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, address to);

    event offerCancled(uint256 indexed offerId, address indexed _tokenAddress, uint256 indexed _tokenId);

}