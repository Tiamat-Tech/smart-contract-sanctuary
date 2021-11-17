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
        uint256[] royalty;
        address[] royaltyAddress;
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
        uint256 tokenId;
        address poster;
        uint256 price;
        //IERC721 tokenContract;
        bytes32 status;
        uint256  timestamp;
    }

      struct Bid {
        address poster;
        uint256 price;
    }

    uint public tradeCounter;
    uint public auctionCounter;
    address public feeAddress;
    uint256 private accessKey;

    mapping(uint256 => Trade) public trades;
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionsBids;
    mapping(uint256 => Offer[]) public offers;
    mapping(uint256 => uint256) public offerCount;
    mapping(uint256 => Royalty) public NFTRoyalty;
    
    constructor (uint256 _accessKey) {
        tradeCounter = 0;
        accessKey=_accessKey;
    }


    function setRoyalty(uint256 _tokenId,uint256[] memory _royalty,address[]  memory _royaltyAddress,uint256 _accessKey ) public  {

        require(accessKey== _accessKey, "You can not access this method directly");
        NFTRoyalty[_tokenId] = Royalty({
            poster: msg.sender,
            royalty:_royalty,
            royaltyAddress:_royaltyAddress
        });

        // TODO : for test  purpose ,to change Later 
        feeAddress = 0xcC118DdeA8A32B04b314126C4151A1875A3CfEb2;
    }
    function openTrade(address _tokenAddress, uint256 _tokenId, uint256 _price) public {

        IERC721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenId);
        trades[tradeCounter+1] = Trade({
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

        Royalty memory  royaltyObj = NFTRoyalty[trade.tokenId];
        uint sendAmount = 0;
        if(royaltyObj.royalty.length>0){
            for( uint i = 0; i<royaltyObj.royalty.length;i++){
                uint256  transferAmount =  trade.price* royaltyObj.royalty[i] ;
                payable(royaltyObj.royaltyAddress[i]).call{value:transferAmount / 10000 }("");
                sendAmount = sendAmount +  royaltyObj.royalty[i];
             }
        }    

        payable(feeAddress).call{value: trade.price * 150 / 10000  }("");
        sendAmount = sendAmount + 150;

       payable(trade.poster).call{value: trade.price * (10000 - sendAmount)  / 10000 }("");
        trade.tokenContract.transferFrom(address(this), msg.sender, trade.tokenId);
        trades[_trade].status = "Executed";
        
        emit tradeExecuted(_trade, address(trade.tokenContract), trade.tokenId, msg.sender);
    }
    function makeTradeOffer(uint256 _price,uint256 _tokenId ) public payable{
        Offer memory _offer = Offer({
            tokenId:_tokenId,
            poster: msg.sender,
           // tokenContract: IERC721(_tokenAddress),
            price: _price,
            status: "Open",
            timestamp:block.timestamp
           
        });

        require(msg.value>=_offer.price, "not enough Ether");
        payable(address(this)).call{value: _offer.price}("");
        offers[_tokenId].push(_offer);
        offerCount[_tokenId]++;
        emit offerMade(offerCount[_tokenId] - 1, feeAddress, _tokenId, _price, msg.sender);
         
    }

    function cancelOffer(uint256 _tokenId, uint256 _offer) public payable{
        Offer memory offer = offers[_tokenId][_offer];

        

        // 	or
        require(msg.sender==offer.poster ," Offer can only be cancelled by poster");
        require(offer.status == "Open", "Offer is not Open");
        payable(offer.poster).call{value: offer.price}("");
        offers[_tokenId][_offer].status="Cancelled";
        //emit offerCancled(_offer, address(offer.tokenContract), _tokenId);
        emit offerCancled(_offer, feeAddress, _tokenId);
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
    
    function acceptOffer(address _tokenAddress, uint256 _tokenId, uint256 _offer,uint256 _trade) public payable{
        Offer memory offer = offers[_tokenId][_offer];

        Offer[] memory openOffers =  offers[_tokenId];

        console.log("open offers",openOffers.length);

         if (_trade != 0){
            Trade memory trade = trades[_trade];
            require(msg.sender == trade.poster, "Offer can be accepted only by poster.");
         }else{
            require(msg.sender == IERC721(_tokenAddress).ownerOf(_tokenId), "You cant accept an offer, for an NFT you dont own");
         }

        
        require(offer.status =="Open", "Offer must be open");
        payable(msg.sender).call{value: offer.price}("");
        IERC721(_tokenAddress).transferFrom(address(this), offer.poster, _tokenId);
        offers[_tokenId][_offer].status="Executed";

         for(uint i = 0; i<openOffers.length;i++){
            if(offers[_tokenId][i].status=="Open"){
                 payable(offers[_tokenId][i].poster).call{value: offers[_tokenId][i].price}("");
            }
        }
       


        if (_trade != 0){ 
             trades[_trade].status = "Closed";
        }


         
        emit offerAccepted(_offer, _tokenAddress, _tokenId, offer.price, offer.poster);
    }


    function rejectOffer(address _tokenAddress, uint256 _tokenId, uint256 _offer,uint256 _trade) public payable{

        Offer memory offer = offers[_tokenId][_offer];
        Trade memory trade =  trades[_trade];

         if (_trade != 0){
            Trade memory trade = trades[_trade];
            require(msg.sender == trade.poster, "Offer can be accepted only by poster.");
         }else{
            require(msg.sender == IERC721(_tokenAddress).ownerOf(_tokenId), "You cant accept an offer, for an NFT you dont own");
         }

        
        require(offer.status =="Open", "Offer must be open");
        payable(offer.poster).call{value: offer.price}("");
        
        offers[_tokenId][_offer].status="Canceled";


         
        emit offerRejected(_offer, _tokenAddress, _tokenId, offer.price, offer.poster);

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

    event offerRejected(uint256 indexed offerId, address indexed _tokenAddress, uint256 indexed _tokenId, uint256 _price, address to);


    event offerCancled(uint256 indexed offerId, address indexed _tokenAddress, uint256 indexed _tokenId);

}