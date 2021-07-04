// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


// Have fun reading it. Hopefully it's bug-free. God bless.

contract NFTLAB is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Auction info
    struct AuctionInfo {
        uint256 lastBid;
        address lastBidder;
        address[] bidders;
        uint finishedAt;
        uint startedAt;
    }

    // Info of each action bid
    struct BidInfo {
        address bidder;
        uint256 amount;
        uint256[] bids;
        uint timestamp;
        bool isLast;
    }

    struct ItemsInfo {
        IERC721 collection;
        address payable owner;
        uint256 tokenid;
        uint256 price;
        address asset;
        bool forSale;
        bool isSold;
        bool isWithdrawn;
        address[] profitTakers;
        uint256[] profitShares;  // from 0 to 10000, very 10000 is 100.00%
        AssetType assetType;
        OrderType orderType;
        AuctionInfo auction;
    }

    struct BuyInfo {
        uint256 timestamp;
        uint256 price;
        address buyer;
    }

    enum AssetType {ETH, ERC20}
    enum OrderType {DIRECT, SIMPLE_AUCTION}

    // fee taker.
    address payable public feeTaker;

    // fee
    uint256 public fee; // 0..100.00% (where 1 is 0.01%) 
    uint256 public feeMax = 3000; // 30.00%
    uint256 public denominator = 10000; // 100.00%

    // permitted erc20
    IERC20[] public allowedTokens;

    // Info of each item.
    ItemsInfo[] public itemsInfo;

    // List of Items by Type
    mapping (OrderType => uint256[]) public itemsByOrderType;
    // Info of each bid.
    mapping (uint256 => mapping (address => BidInfo)) public bidsItemInfo;

    mapping (uint256 => BuyInfo[]) public buyItemInfo;

    constructor(address payable _feeTaker, uint256 _fee) {
        require(_fee <= denominator,
                "fee should be great or equal to 0 and less than 100.00%");
        feeTaker = _feeTaker;
        fee = _fee;
    }

    function getItemsLength()
        external view returns (uint256)
    {
        return itemsInfo.length;
    }

    function isAllowedToken(IERC20 _token)
        public view returns (bool) 
    {
        for(uint idx=0; idx < allowedTokens.length; idx++) {
            if(allowedTokens[idx] == _token) {
                return true;
            }
        }
        return false;
    }

    function tokensLength()
        external view returns (uint256)
    {
        return allowedTokens.length;
    }

    function add(IERC20 _token)
        public onlyOwner
    {
        require(isAllowedToken(_token) == false, "should be added once time");
        allowedTokens.push(_token);
    }

    // Update fee address
    function setFeeTaker(address payable _addr)
        public onlyOwner
    {
        feeTaker = _addr;
    }

    function setFee(uint256 _fee)
        public onlyOwner
    {
        require(_fee>= 0 && _fee <= feeMax, "Not Number");
        fee = _fee;
    }

    function cancelAuction(uint256 _itemId)
        public onlyOwner
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.orderType == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.isSold == false, "Not for sale!");

        AuctionInfo storage auctionInfo = item.auction;
        if(auctionInfo.lastBid>0) {
            if(item.assetType == AssetType.ERC20) {
                IERC20 token = IERC20(item.asset);
                token.safeTransfer(
                    address(auctionInfo.lastBidder),
                    auctionInfo.lastBid
                );
            } else {
                payable(auctionInfo.lastBidder).transfer(auctionInfo.lastBid);
            }
        }

        itemCollection.safeTransferFrom(
            address(this), address(item.owner), item.tokenid
        );
        item.auction.finishedAt = block.timestamp;
        item.isSold = false;
        item.forSale = false;
    }

    function placeItem(
        IERC721 _collection,
        uint256 _tokenId,
        uint256 _price,
        address _asset,
        bool _forSale,
        uint256 _startedAt,
        address[] memory _profitTakers,
        uint256[] memory _profitShares, // from 0 to 10000, very 10000 is 100.00%
        AssetType _assetType,
        OrderType _orderType
    ) 
        public onlyOwner
    {
        require(_orderType == OrderType.DIRECT || _orderType == OrderType.SIMPLE_AUCTION,
                "only direct order type and auction is possible");

        require(_forSale == true,
                "permited only auction for sale");

        require(_assetType == AssetType.ETH || _assetType == AssetType.ERC20,
                "only erc20 or eth asset type permitted for auction");

        require(_startedAt != 0,
                "started at is required");

        require(_startedAt >= (block.timestamp - 86400),
                "startedAt should be greater or equal than block.timestamp - 86400");

        {
            // sum of all shares + fee should be equal to 100.00%
            require(_profitShares.length == _profitTakers.length,
                    "num of shares should be equal to num of takers");
            uint256 shares;
            if(_orderType == OrderType.DIRECT) {
                // fee over 100.00% for DIRECT sale
                shares = 10000;
            } else {
                // fee in 100.00% for AUCTION sale
                shares = 10000 - fee;
            }
            for(uint256 i=0;i < _profitTakers.length;i++) {
                require(shares - _profitShares[i] >= 0,
                        "all shares should be lower or equal to 100.00 - fee");
                shares = shares - _profitShares[i];
            }
            require(shares == 0,
                    "after all distribution check shares amount is not equal to 0");
        }

        if(_assetType == AssetType.ETH) {
            require(_asset == address(0), "_asset should be zero for ETH asset type");
        }
        _collection.transferFrom(address(msg.sender), address(this), _tokenId);
        AuctionInfo memory auctionInfo;
        address[] memory bidders;
        auctionInfo.lastBid = 0;
        auctionInfo.finishedAt = 0;
        auctionInfo.startedAt = _startedAt;
        auctionInfo.lastBidder = address(0x0);
        auctionInfo.bidders = bidders;

        itemsInfo.push(ItemsInfo({
            collection: _collection,
            owner: payable(msg.sender),
            tokenid: _tokenId,
            price: _price,
            asset: _asset,
            forSale: _forSale,
            isSold: false,
            isWithdrawn: false,
            profitTakers: _profitTakers,
            profitShares: _profitShares,
            assetType: _assetType,
            orderType: _orderType,
            auction: auctionInfo
        }));
        itemsByOrderType[_orderType].push(itemsInfo.length - 1);
    }

    function _distributeProfitToTakers(
        ItemsInfo memory item,
        uint256 _price,
        uint256 _fee 
    )
        internal returns (uint256) 
    {
        if(item.assetType == AssetType.ETH) {
            return _distributeProfitToTakersForETH(item, _price, _fee);
        } else if(item.assetType == AssetType.ERC20) {
            return _distributeProfitToTakersForErc20(item, _price, _fee);
        }
        revert();
    }

    function _distributeProfitToTakersForETH(
        ItemsInfo memory item,
        uint256 _price,
        uint256 _fee
    )
        internal returns (uint256) 
    {

        uint256 distributedProfit = _fee;
        // Transfer fee
        if(_fee > 0) 
            feeTaker.transfer(_fee);

        // Distribute profit in ETH to all parties
        for(uint256 i=0; i < item.profitTakers.length; i++) {
            address taker = item.profitTakers[i];
            uint256 share = item.profitShares[i];
            uint256 amount = _price.mul(share).div(denominator);
            payable(taker).transfer(amount);
            distributedProfit = distributedProfit.add(amount);
        }
        return distributedProfit;
    }

    function _distributeProfitToTakersForErc20(
        ItemsInfo memory item,
        uint256 _price,
        uint256 _fee
    )
        internal returns (uint256) 
    {

        uint256 distributedProfit = _fee;
        IERC20 token = IERC20(item.asset);
        // Transfer fee
        if(_fee > 0) 
            token.safeTransfer(feeTaker, _fee);

        // Distribute profit in ETH to all parties
        for(uint256 i=0; i < item.profitTakers.length; i++) {
            address taker = item.profitTakers[i];
            uint256 share = item.profitShares[i];
            uint256 amount = _price.mul(share).div(denominator);
            token.safeTransfer(taker, amount);
            distributedProfit = distributedProfit.add(amount);

        }
        return distributedProfit;
    }

    function changePriceOnMarket(uint256 _itemId, uint256 _newPrice)
        public onlyOwner 
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.owner == msg.sender, "Not owner!");
        item.price = _newPrice;
    }

    function withdrawItemFromMarket(uint256 _itemId)
        public onlyOwner
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.owner == msg.sender, "Not owner!");
        itemCollection.safeTransferFrom(address(this), address(msg.sender), item.tokenid);
        item.isWithdrawn = true;
    }

    function buyItemFromMarket(uint256 _itemId)
        public
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.orderType == OrderType.DIRECT, "Only direct buy!");
        require(item.forSale == true, "Already sold!");
        require(item.assetType == AssetType.ERC20, "Only for ERC20!");

        uint256 feeAmount = item.price.mul(fee).div(denominator);
        uint256 shouldBeDistributed = feeAmount.add(item.price);
        uint256 _distributedProfit = _distributeProfitToTakers(item, item.price, feeAmount);
        require(_distributedProfit == shouldBeDistributed);

        itemCollection.safeTransferFrom(address(this), address(msg.sender), item.tokenid);

        item.isSold = true;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp: block.timestamp,
            price: _distributedProfit,
            buyer: msg.sender 
        }));
    }

    function buyItemFromMarketForEth(uint256 _itemId)
        public payable
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.orderType == OrderType.DIRECT, "Only direct buy!");
        require(item.forSale == true, "Already sold!");
        require(item.assetType == AssetType.ETH, "Only for ETH!");

        uint256 feeAmount = item.price.mul(fee).div(denominator);
        uint256 shouldBeDistributed = feeAmount.add(item.price);
        require(msg.value >= shouldBeDistributed, "ETH amount is lower than expected");
        uint256 _distributedProfit = _distributeProfitToTakers(item, item.price, feeAmount);
        require(_distributedProfit == shouldBeDistributed);
        itemCollection.safeTransferFrom(address(this), address(msg.sender), item.tokenid);

        item.isSold = true;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp:block.timestamp,
            price:_distributedProfit,
            buyer:msg.sender 
        }));
    }

    function finishAuction(uint256 _itemId)
        public onlyOwner
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.auction.bidders.length > 0,
                "It is possible to finish only bidded auctions");
        require(item.orderType == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");

        AuctionInfo storage auctionInfo = item.auction;

        uint256 feeAmount = auctionInfo.lastBid.mul(fee).div(denominator);
        // uint256 priceWithoutDevFee = auctionInfo.lastBid.sub(feeAmount);
        uint256 distributedProfit = _distributeProfitToTakers(
            item, auctionInfo.lastBid, feeAmount
        );
        require(distributedProfit == auctionInfo.lastBid,
               "distributedProfit should be equal to lastBid");

        itemCollection.safeTransferFrom(
            address(this), address(auctionInfo.lastBidder), item.tokenid
        );
        item.auction.finishedAt = block.timestamp;
        item.isSold = true;
        item.forSale = false;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp:block.timestamp,
            price:auctionInfo.lastBid,
            buyer:auctionInfo.lastBidder 
        }));
    }

    function _submitBidForErc20(uint256 _itemId, uint256 _bidPrice)
        internal
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.orderType == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.assetType == AssetType.ERC20, "Only for ERC20!");
        require(msg.value == 0, "Ether is not permit");

        IERC20 token = IERC20(item.asset);
        uint256 tokenBalance = token.balanceOf(address(msg.sender));
        BidInfo storage bidInfo = bidsItemInfo[_itemId][msg.sender];
        AuctionInfo storage auctionInfo = item.auction;

        require(tokenBalance > item.price, "new bid should be greater than minimal item price");
        require(tokenBalance > auctionInfo.lastBid, "new bid should be greater than last");

        token.safeTransferFrom(address(msg.sender), address (this), _bidPrice);

        if(auctionInfo.lastBidder != address(0x0)) {
            token.safeTransfer(auctionInfo.lastBidder, auctionInfo.lastBid);
            bidsItemInfo[_itemId][auctionInfo.lastBidder].isLast = false;
        }

        auctionInfo.lastBid = _bidPrice;
        auctionInfo.lastBidder = msg.sender;

        // for each first bid store bidder to auction bidders list
        if(bidInfo.bidder == address(0x0)) {
            bidInfo.bidder = msg.sender;
            auctionInfo.bidders.push(msg.sender);
        }
        bidInfo.amount = _bidPrice;
        bidInfo.isLast = true;
        bidInfo.timestamp = block.timestamp;
        bidInfo.bids.push(_bidPrice);
    }

    function _submitBidForEth(uint256 _itemId)
        internal
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.orderType == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.assetType == AssetType.ETH, "Only for ETH!");

        BidInfo storage bidInfo = bidsItemInfo[_itemId][msg.sender];
        AuctionInfo storage auctionInfo = item.auction;

        require(msg.value > item.price, "new bid should be greater than minimal item price");
        require(msg.value > auctionInfo.lastBid, "new bid should be greater than last");

        if(auctionInfo.lastBidder != address(0x0)) {
            payable(auctionInfo.lastBidder).transfer(auctionInfo.lastBid);
            bidsItemInfo[_itemId][auctionInfo.lastBidder].isLast = false;
        }
        auctionInfo.lastBid = msg.value;
        auctionInfo.lastBidder = msg.sender;

        // for each first bid store bidder to auction bidders list
        if(bidInfo.bidder == address(0x0)) {
            bidInfo.bidder = msg.sender;
            auctionInfo.bidders.push(msg.sender);
        }
        bidInfo.amount = msg.value;
        bidInfo.isLast = true;
        bidInfo.bids.push(msg.value);
    }

    function submitBid(uint256 _itemId, uint256 _bidPrice)
        public payable
    {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.orderType == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        if(item.assetType == AssetType.ETH) {
            require(_bidPrice == 0, "For eth _bidPrice should be 0");
            _submitBidForEth(_itemId);
        } else if(item.assetType == AssetType.ERC20) {
            require(msg.value == 0, "For erc20 msg.value should be 0");
            _submitBidForErc20(_itemId, _bidPrice);
        }
    }

    function getAuctionInfo(uint256 _tokenid)
        view  public returns (AuctionInfo memory)
    {
        return(itemsInfo[_tokenid].auction);
    } 

    function getItems(OrderType _orderType)
        view  public returns (ItemsInfo[] memory)
    {
        uint256[] memory itemIds = itemsByOrderType[_orderType];
        ItemsInfo[] memory items = new ItemsInfo[](itemIds.length);
        for(uint idx=0; idx < itemIds.length; idx++) {
            items[idx] = itemsInfo[itemIds[idx]];
        }
        return(items);
    }

    function getAuctions()
        view  public returns (ItemsInfo[] memory)
    {
        return getItems(OrderType.SIMPLE_AUCTION);
    }
   
    function getDirectItems()
        view  public returns (ItemsInfo[] memory)
    {
        return getItems(OrderType.DIRECT);
    }

    function getAuctionBids(uint256 _tokenid)
        view public returns (BidInfo[] memory)
    {
        ItemsInfo storage item = itemsInfo[_tokenid];
        AuctionInfo memory auctionInfo = item.auction;
        BidInfo[] memory bids = new BidInfo[](auctionInfo.bidders.length);
        for(uint idx;idx<auctionInfo.bidders.length;idx++) {
            bids[idx] = getBidInfo(_tokenid, auctionInfo.bidders[idx]);
        }
        return bids;
    }

    function getBidInfo(uint256 _tokenid, address _bidder)
        public view returns(BidInfo memory)
    {
        return bidsItemInfo[_tokenid][_bidder];
    }

    function getBuyItemInfo(uint256 _tokenid)
        view public returns (BuyInfo[] memory)
    {
        return(buyItemInfo[_tokenid]);
    }
}