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

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of token contract.
    }

    // Auction info
    struct AuctionInfo {
        uint256 last_bid;
        address last_bidder;
        address[] bidders;
        uint finished_at;
        uint started_at;
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
        address payable referral;
        uint256 tokenid;
        uint256 price;
        uint256 pool_id;
        bool forSale;
        bool isSold;
        bool isWithdrawn;
        uint256 refComission;
        AssetType asset_type;
        OrderType order_type;
        AuctionInfo auction;
    }

    struct BuyInfo {
        uint256 timestamp;
        uint256 price;
        address buyer;
    }

    enum AssetType {ETH, ERC20}
    enum OrderType {DIRECT, SIMPLE_AUCTION}

    // Dev fee taker.
    address payable public devFeeTaker;
    //  dev comission
    uint256 public devFee;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each item.
    ItemsInfo[] public itemsInfo;

    // List of Items by Type
    mapping (OrderType => uint256[]) public itemsByOrderType;
    // Info of each bid.
    mapping (uint256 => mapping (address => BidInfo)) public bidsItemInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    mapping (uint256 => BuyInfo[]) public buyItemInfo;

    constructor(address payable _devaddr, uint256 _devFee) {
        devFeeTaker = _devaddr;
        devFee = _devFee;
    }

    function getItemsLength() external view returns (uint256) {
        return itemsInfo.length;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(IERC20 _lpToken) public onlyOwner {
        poolInfo.push(PoolInfo({
            lpToken: _lpToken
        }));
    }

    // Update dev address by the previous dev.
    function dev(address payable _devaddr) public onlyOwner {
        require(msg.sender == devFeeTaker, "dev: wut?");
        devFeeTaker = _devaddr;
    }

    function placeItem(
        IERC721 _collection,
        uint256 _tokenId,
        uint256 _price,
        uint256 _pool_id,
        bool _forSale,
        address payable _referral,
        uint256 _refComission,
        AssetType _asset_type,
        OrderType _order_type
    ) public onlyOwner {
        require(_order_type == OrderType.DIRECT || _order_type == OrderType.SIMPLE_AUCTION,
                "only direct order type and auction is possible");

        require(_asset_type == AssetType.ETH || _asset_type == AssetType.ERC20,
                "only erc20 or eth asset type permitted for auction");

        if(_asset_type == AssetType.ETH) {
            require(_pool_id == 0, "_pool_id should be zero for ETH asset type");
        }

        _collection.transferFrom(address(msg.sender), address(this), _tokenId);
        AuctionInfo memory auction_info;
        address[] memory bidders;
        auction_info.last_bid = 0;
        auction_info.finished_at = 0;
        auction_info.started_at = block.timestamp;
        auction_info.last_bidder = address(0x0);
        auction_info.bidders = bidders;

        itemsInfo.push(ItemsInfo({
            collection: _collection,
            owner: payable(msg.sender),
            referral: _referral,
            refComission: _refComission,
            tokenid: _tokenId,
            price: _price,
            pool_id: _pool_id,
            forSale: _forSale,
            isSold: false,
            isWithdrawn: false,
            asset_type: _asset_type,
            order_type: _order_type,
            auction: auction_info
        }));
        itemsByOrderType[_order_type].push(itemsInfo.length - 1);
    }

    function changePriceOnMarket(uint256 _itemId, uint256 _newPrice) public onlyOwner {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.owner == msg.sender, "Not owner!");
        item.price = _newPrice;
    }

    function withdrawItemFromMarket(uint256 _itemId) public onlyOwner {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.owner == msg.sender, "Not owner!");
        itemCollection.safeTransferFrom(address(this), address(msg.sender), item.tokenid);
        item.isWithdrawn = true;
    }

    function buyItemFromMarket(uint256 _itemId) public {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.order_type == OrderType.DIRECT, "Only direct buy!");
        require(item.forSale == true, "Already sold!");
        require(item.asset_type == AssetType.ERC20, "Only for ERC20!");

        IERC20 token = poolInfo[ item.pool_id ].lpToken;
        uint256 priceWithDevFee = item.price + item.price.mul(1e10).mul(devFee).div(1e12);
        uint256 refComission = item.price.mul(1e10).mul(item.refComission).div(1e12);
        uint256 toOwnerAmount = item.price.sub(item.price.mul(1e10).mul(item.refComission).div(1e12));

        token.safeTransferFrom(address(msg.sender), address (this), item.price.mul(1e10).mul(devFee).div(1e12));
        token.safeTransferFrom(address(msg.sender), address (item.owner), toOwnerAmount);
        token.safeTransferFrom(address(msg.sender), address (item.referral), refComission);
        itemCollection.safeTransferFrom(address(this), address(msg.sender), item.tokenid);

        item.isSold = true;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp:block.timestamp,
            price:priceWithDevFee,
            buyer:msg.sender 
        }));
    }

    function buyItemFromMarketForEth(uint256 _itemId) public payable {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.order_type == OrderType.DIRECT, "Only direct buy!");
        require(item.forSale == true, "Already sold!");
        require(item.asset_type == AssetType.ETH, "Only for ETH!");

        uint256 devFeeAmount = item.price.mul(1e10).mul(devFee).div(1e12);
        uint256 priceWithDevFee = item.price.add(devFeeAmount);
        uint256 refComission = item.price.mul(1e10).mul(item.refComission).div(1e12);
        uint256 toOwnerAmount = item.price.sub(refComission);

        require(msg.value >= priceWithDevFee);

        item.owner.transfer(toOwnerAmount);
        item.referral.transfer(refComission);
        devFeeTaker.transfer(devFeeAmount);

        itemCollection.safeTransferFrom(address(this), address(msg.sender), item.tokenid);

        item.isSold = true;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp:block.timestamp,
            price:priceWithDevFee,
            buyer:msg.sender 
        }));
    }

    function _finishAuctionErc20(ItemsInfo memory item, AuctionInfo memory auction_info) internal {
        require(item.asset_type == AssetType.ERC20, "Only for ERC20!");

        uint256 devFeeAmount = auction_info.last_bid.mul(1e10).mul(devFee).div(1e12);
        uint256 priceWithoutDevFee = auction_info.last_bid.sub(devFeeAmount);
        uint256 refComission = priceWithoutDevFee.mul(1e10).mul(item.refComission).div(1e12);
        uint256 toOwnerAmount = priceWithoutDevFee.sub(refComission);
        IERC20 token = poolInfo[ item.pool_id ].lpToken;

        if(refComission > 0) {
            token.safeTransfer(item.referral, refComission);
        }
        if(devFeeAmount > 0) {
            token.safeTransfer(devFeeTaker, devFeeAmount);
        }
        token.safeTransfer(item.owner, toOwnerAmount);
    }

    function _finishAuctionEth(ItemsInfo memory item, AuctionInfo memory auction_info) internal {
        require(item.asset_type == AssetType.ETH, "Only for ETH!");

        uint256 devFeeAmount = auction_info.last_bid.mul(1e10).mul(devFee).div(1e12);
        uint256 priceWithoutDevFee = auction_info.last_bid.sub(devFeeAmount);
        uint256 refComission = priceWithoutDevFee.mul(1e10).mul(item.refComission).div(1e12);
        uint256 toOwnerAmount = priceWithoutDevFee.sub(refComission);

        if(refComission > 0) {
            item.referral.transfer(refComission);
        }
        if(devFeeAmount > 0) {
            devFeeTaker.transfer(devFeeAmount);
        }
        item.owner.transfer(toOwnerAmount);
    }

    function finishAuction(uint256 _itemId) public onlyOwner {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.order_type == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");

        AuctionInfo storage auction_info = item.auction;

        if(item.asset_type == AssetType.ETH) {
            _finishAuctionEth(item, auction_info);
        } else if(item.asset_type == AssetType.ERC20) {
            _finishAuctionErc20(item, auction_info);
        }

        itemCollection.safeTransferFrom(address(this), address(auction_info.last_bidder), item.tokenid);
        item.auction.finished_at = block.timestamp;
        item.forSale = false;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp:block.timestamp,
            price:auction_info.last_bid,
            buyer:auction_info.last_bidder 
        }));
    }

    function _submitBidForErc20(uint256 _itemId, uint256 _bid_price) internal {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.order_type == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.asset_type == AssetType.ERC20, "Only for ERC20!");
        require(msg.value == 0, "Ether is not permit");

        IERC20 token = poolInfo[ item.pool_id ].lpToken;
        uint256 token_balance = token.balanceOf(address(msg.sender));
        BidInfo storage bid_info = bidsItemInfo[_itemId][msg.sender];
        AuctionInfo storage auction_info = item.auction;

        require(token_balance > item.price, "new bid should be greater than minimal item price");
        require(token_balance > auction_info.last_bid, "new bid should be greater than last");

        token.safeTransferFrom(address(msg.sender), address (this), _bid_price);

        if(auction_info.last_bidder != address(0x0)) {
            token.safeTransfer(auction_info.last_bidder, auction_info.last_bid);
            bidsItemInfo[_itemId][auction_info.last_bidder].isLast = false;
        }

        auction_info.last_bid = _bid_price;
        auction_info.last_bidder = msg.sender;

        // for each first bid store bidder to auction bidders list
        if(bid_info.bidder == address(0x0)) {
            bid_info.bidder = msg.sender;
            auction_info.bidders.push(msg.sender);
        }
        bid_info.amount = _bid_price;
        bid_info.isLast = true;
        bid_info.timestamp = block.timestamp;
        bid_info.bids.push(_bid_price);
    }

    function _submitBidForEth(uint256 _itemId) internal {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.order_type == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.asset_type == AssetType.ETH, "Only for ETH!");

        BidInfo storage bid_info = bidsItemInfo[_itemId][msg.sender];
        AuctionInfo storage auction_info = item.auction;

        require(msg.value > item.price, "new bid should be greater than minimal item price");
        require(msg.value > auction_info.last_bid, "new bid should be greater than last");

        if(auction_info.last_bidder != address(0x0)) {
            payable(auction_info.last_bidder).transfer(auction_info.last_bid);
            bidsItemInfo[_itemId][auction_info.last_bidder].isLast = false;
        }
        auction_info.last_bid = msg.value;
        auction_info.last_bidder = msg.sender;

        // for each first bid store bidder to auction bidders list
        if(bid_info.bidder == address(0x0)) {
            bid_info.bidder = msg.sender;
            auction_info.bidders.push(msg.sender);
        }
        bid_info.amount = msg.value;
        bid_info.isLast = true;
        bid_info.bids.push(msg.value);
    }

    function submitBid(uint256 _itemId, uint256 _bid_price) public payable {
        ItemsInfo storage item = itemsInfo[_itemId];
        require(item.order_type == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        if(item.asset_type == AssetType.ETH) {
            require(_bid_price == 0, "For eth _bid_price should be 0");
            _submitBidForEth(_itemId);
        } else if(item.asset_type == AssetType.ERC20) {
            require(msg.value == 0, "For erc20 msg.value should be 0");
            _submitBidForErc20(_itemId, _bid_price);
        }
    }

    function getAuctionInfo(uint256 _tokenid) view  public returns (AuctionInfo memory) {
        return(itemsInfo[_tokenid].auction);
    } 
   
    function getDirectItems() view  public returns (ItemsInfo[] memory) {
        return getItems(OrderType.DIRECT);
    }

    function getItems(OrderType _order_type) view  public returns (ItemsInfo[] memory) {
        uint256[] memory item_ids = itemsByOrderType[_order_type];
        ItemsInfo[] memory items = new ItemsInfo[](item_ids.length);
        for(uint idx=0; idx < item_ids.length; idx++) {
            items[idx] = itemsInfo[item_ids[idx]];
        }
        return(items);
    }

    function getAuctions() view  public returns (ItemsInfo[] memory) {
        return getItems(OrderType.SIMPLE_AUCTION);
    }

    function getAuctionBids(uint256 _tokenid) view public returns (BidInfo[] memory) {
        ItemsInfo storage item = itemsInfo[_tokenid];
        AuctionInfo memory auction_info = item.auction;
        BidInfo[] memory bids = new BidInfo[](auction_info.bidders.length);
        for(uint idx;idx<auction_info.bidders.length;idx++) {
            bids[idx] = getBidInfo(_tokenid, auction_info.bidders[idx]);
        }
        return bids;
    }

    function getBidInfo(uint256 _tokenid, address _bidder) public view returns(BidInfo memory){
        return bidsItemInfo[_tokenid][_bidder];
    }

    function changeDevComission(uint256 _devFee) public onlyOwner {
        require(_devFee >0 , "Not Number");
        devFee = _devFee;
    }

    function getBuyItemInfo(uint256 _tokenid) view public returns (BuyInfo[] memory) {
        return(buyItemInfo[_tokenid]);
    }
}