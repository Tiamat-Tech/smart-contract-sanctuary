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
    }

    // Info of each action bid
    struct BidInfo {
        uint256 amount;
        uint256[] bids;
        bool isRevoked;
    }

    struct ItemsInfo {
        IERC721 collection;
        address payable owner;
        address payable referral;
        uint256 tokenid;
        uint256 price;
        uint256 poolToken;
        bool forSale;
        bool isSold;
        bool isWithdrawn;
        uint256 refComission;
        AssetType asset_type;
        OrderType order_type;
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
    // Info of each bid.
    mapping (uint256 => mapping (address => BidInfo)) public bidsItemInfo;
    mapping (uint256 => AuctionInfo) public auctionItemInfo;
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
        uint256 _poolToken,
        bool _forSale,
        address payable _referral,
        uint256 _refComission,
        AssetType _asset_type,
        OrderType _order_type
    ) public onlyOwner {
        require(_order_type == OrderType.DIRECT || _order_type == OrderType.SIMPLE_AUCTION,
                "only direct order type and auction is possible");

        uint256 poolToken = 0;
        if (_asset_type == AssetType.ERC20) {
            require(_poolToken != 0x0, "poolToken should be address");
            poolToken = _poolToken;
        } else if (_asset_type == AssetType.ETH) {
            require(_poolToken == 0x0, "poolToken should be 0x0");
        } else {
            revert("asset_type only should be ERC20 or ETH");
        }

        _collection.transferFrom(address(msg.sender), address(this), _tokenId);
        itemsInfo.push(ItemsInfo({
            collection: _collection,
            owner: payable(msg.sender),
            referral: _referral,
            refComission : _refComission,
            tokenid: _tokenId,
            price: _price,
            poolToken: poolToken,
            forSale: _forSale,
            isSold: false,
            isWithdrawn: false,
            asset_type: _asset_type,
            order_type: _order_type
        }));
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

        uint256 priceWithDevFee = item.price + item.price.mul(1e10).mul(devFee).div(1e12);
        uint256 refComission = item.price.mul(1e10).mul(item.refComission).div(1e12);
        uint256 toOwnerAmount = item.price.sub(item.price.mul(1e10).mul(item.refComission).div(1e12));

        poolInfo[ item.poolToken ].lpToken.safeTransferFrom(address(msg.sender), address (this), item.price.mul(1e10).mul(devFee).div(1e12));
        poolInfo[ item.poolToken ].lpToken.safeTransferFrom(address(msg.sender), address (item.owner), toOwnerAmount);
        poolInfo[ item.poolToken ].lpToken.safeTransferFrom(address(msg.sender), address (item.referral), refComission);
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

    function finishAuction(uint256 _itemId) public onlyOwner {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.order_type == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.asset_type == AssetType.ETH, "Only for ETH!");

        AuctionInfo storage auction_info = auctionItemInfo[_itemId];
        BidInfo storage winner_bid_info = bidsItemInfo[_itemId][auction_info.last_bidder];
        for(uint idx = 0; idx < auction_info.bidders.length; idx++) {
            address payable bidder = payable(auction_info.bidders[idx]);
            if(bidder == auction_info.last_bidder) {
                continue;
            }
            BidInfo storage bid_info = bidsItemInfo[_itemId][bidder];
            bidder.transfer(bid_info.amount);

        }
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

        itemCollection.safeTransferFrom(address(this), address(auction_info.last_bidder), item.tokenid);

        item.isSold = true;
        item.forSale = false;
        buyItemInfo[item.tokenid].push(BuyInfo({
            timestamp:block.timestamp,
            price:auction_info.last_bid,
            buyer:auction_info.last_bidder 
        }));
    }

    function submitBid(uint256 _itemId) public payable {
        ItemsInfo storage item = itemsInfo[_itemId];
        IERC721 itemCollection = item.collection;
        require(item.order_type == OrderType.SIMPLE_AUCTION, "Only auction!");
        require(item.forSale == true, "Not for sale!");
        require(item.asset_type == AssetType.ETH, "Only for ETH!");

        BidInfo storage bid_info = bidsItemInfo[_itemId][msg.sender];
        AuctionInfo storage auction_info = auctionItemInfo[_itemId];
        uint256 new_bid = bid_info.amount + msg.value;

        require(new_bid > auction_info.last_bid, "new bid should be greater than last");

        auction_info.last_bid = new_bid;
        auction_info.last_bidder = msg.sender;

        // for each first bid store bidder to auction bidders list
        if(bid_info.bids.length == 0) {
            auction_info.bidders.push(msg.sender);
        }
        bid_info.amount += msg.value;
        bid_info.bids.push(msg.value);
    }

    function getAuctionInfo(uint256 _tokenid) view  public returns (AuctionInfo memory) {
        return(auctionItemInfo[_tokenid]);
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