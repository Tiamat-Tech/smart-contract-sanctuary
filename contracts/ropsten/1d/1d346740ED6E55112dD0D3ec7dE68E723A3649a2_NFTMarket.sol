// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./access/TwoStageOwnable.sol";
import "./utils/StringUtils.sol";
import "./interfaces/INFT.sol";
import "./interfaces/IMarket.sol";

contract NFTMarket is IMarket, ReentrancyGuard, TwoStageOwnable, ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using StringUtils for string;

    uint256 constant HUNDRED_PERCENT = 10000;

    uint256 private _itemIds;
    uint256 private _feeOracle;
    uint256 private _lastItemId;
    address private _nupayWalletAddress;
    address private _oracle;
    bytes32 private _jobId;
    string private _urlRequest;
    bool private _initialized;
    bool private _stopped;
    IMarket private _fromMarket;
    IMarket private _toMarket;
    IERC20 private _linkToken;
    INFT private _nftContract;

    mapping(uint256 => MarketItem) private _idToMarketItem;
    // idToken => idMarketItems[]
    mapping(uint256 => uint256[]) private _idTokenToIdMarketItems;
    // Request id => Market item id
    mapping(bytes32 => uint256) private _reqIds;
    // TokenId => MarketId
    mapping(uint256 => uint256) private _idTokenToMarket;

    function bytes32ToString(bytes32 _bytes32) private pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function fetchAllMarketItems(uint256 skip, uint256 limit) external view returns (MarketItem[] memory marketItems) {
        if (skip > _itemIds) return marketItems;
        uint256 to = skip + limit;
        if (_itemIds < to) to = _itemIds;
        uint256 length = to - skip;
        marketItems = new MarketItem[](length);
        MarketItem[] memory previousMarketItems;
        if (_lastItemId > 0 && skip <= _lastItemId) {
            previousMarketItems = _fromMarket.fetchAllMarketItems(skip, limit);
        }
        uint256 previousLength = previousMarketItems.length;
        for (uint256 i = 0; i < length; i++) {
            marketItems[i] = i < previousLength ? previousMarketItems[i] : _idToMarketItem[skip + i + 1];
        }
    }

    function fetchMarketItemsByTokenId(
        uint256 tokenId,
        uint256 skip,
        uint256 limit
    ) external view returns (MarketItem[] memory marketItems) {
        uint256[] memory marketItemsByTokenId = _idTokenToIdMarketItems[tokenId];
        uint256 marketItemsLength = marketItemsByTokenIdLength(tokenId);
        if (skip >= marketItemsLength) return marketItems;
        uint256 to = skip + limit;
        if (marketItemsLength < to) to = marketItemsLength;
        uint256 length = to - skip;
        marketItems = new MarketItem[](length);
        MarketItem[] memory previousMarketItems;
        if (_lastItemId > 0 && skip <= _lastItemId) {
            previousMarketItems = _fromMarket.fetchMarketItemsByTokenId(tokenId, skip, limit);
        }
        uint256 previousLength = previousMarketItems.length;
        uint256 pad = 0;
        for (uint256 i = 0; i < length; i++) {
            if (i < previousLength) {
                marketItems[i] = previousMarketItems[i];
                pad = i + 1;
            } else {
                marketItems[i] = _idToMarketItem[marketItemsByTokenId[i - pad]];
            }
        }
    }

    function fetchSpecificMarketItem(uint256 itemId) public view returns (MarketItem memory marketItem) {
        marketItem = (_lastItemId > 0 && itemId <= _lastItemId)
            ? _fromMarket.fetchSpecificMarketItem(itemId)
            : _idToMarketItem[itemId];
    }

    function feeOracle() external view returns (uint256) {
        return _feeOracle;
    }

    function fromMarket() external view returns (address) {
        return address(_fromMarket);
    }

    function toMarket() external view override returns (address) {
        return address(_toMarket);
    }

    function initialized() external view returns (bool) {
        return _initialized;
    }

    function idTokenToMarket(uint256 tokenId) public view returns (uint256 itemId) {
        itemId = (_idTokenToMarket[tokenId] == 0 && _lastItemId > 0)
            ? _fromMarket.idTokenToMarket(tokenId)
            : _idTokenToMarket[tokenId];
    }

    function itemIds() external view returns (uint256) {
        return _itemIds;
    }

    function lastItemId() external view returns (uint256) {
        return _lastItemId;
    }

    function linkToken() external view returns (address) {
        return address(_linkToken);
    }

    function marketItemsByTokenIdLength(uint256 tokenId) public view returns (uint256 length) {
        if (address(_fromMarket) != address(0)) {
            length = _fromMarket.marketItemsByTokenIdLength(tokenId);
        }
        length += _idTokenToIdMarketItems[tokenId].length;
    }

    function nftContract() external view returns (address) {
        return address(_nftContract);
    }

    function nupayWalletAddress() external view returns (address) {
        return _nupayWalletAddress;
    }

    function oracle() external view returns (address, bytes32) {
        return (_oracle, _jobId);
    }

    function reqIds(bytes32 reqId) external view returns (uint256) {
        return _reqIds[reqId];
    }

    function stopped() external view returns (bool) {
        return _stopped;
    }

    function urlRequest() external view returns (string memory) {
        return _urlRequest;
    }

    event AssetsDistributed(uint256 itemId);
    event AssetsForciblyDistributed(uint256 itemId);
    event DealResolved(uint256 itemId);
    event DealRejected(uint256 itemId);
    event MarketItemCreated(address indexed seller, uint256 itemId, uint256 tokenId, uint256 price);
    event MarketSaleCreated(address indexed buyer, uint256 itemId);

    constructor(
        address owner_,
        string memory urlRequest_,
        address linkToken_,
        address nupayWalletAddress_,
        address oracle_,
        bytes32 jobId_,
        uint256 feeOracle_
    ) TwoStageOwnable(owner_) {
        address zero = address(0);
        require(owner_ != zero, "Owner is zero address");
        require(oracle_ != zero, "Oracle is zero address");
        require(linkToken_ != zero, "Link token is zero address");
        require(nupayWalletAddress_ != zero, "Nupay wallet is zero address");
        setChainlinkToken(linkToken_);
        _linkToken = IERC20(linkToken_);
        _urlRequest = urlRequest_;
        _nupayWalletAddress = nupayWalletAddress_;
        _oracle = oracle_;
        _jobId = jobId_;
        _feeOracle = feeOracle_;
    }

    function createMarketItem(uint256 tokenId, uint256 price) external whenNotStopped returns (bool) {
        _itemIds++;
        address seller = msg.sender;
        require(seller == _nftContract.ownerOf(tokenId), "Seller not owner tokenId");
        MarketItem storage marketItem = _idToMarketItem[_itemIds];
        marketItem.itemId = _itemIds;
        marketItem.tokenId = tokenId;
        marketItem.seller = payable(seller);
        marketItem.price = price;
        _idTokenToIdMarketItems[tokenId].push(_itemIds);
        emit MarketItemCreated(seller, _itemIds, tokenId, price);
        return true;
    }

    function createMarketSale(uint256 itemId) external payable whenNotStopped nonReentrant returns (bool) {
        require(itemId > 0 && itemId <= _itemIds, "Market item not exist");
        MarketItem memory item = fetchSpecificMarketItem(itemId);
        address caller = msg.sender;
        require(caller != item.seller, "Caller is seller");
        require(msg.value == item.price, "Insufficient amount");
        require(!item.sold, "Item already paid");
        require(idTokenToMarket(item.tokenId) == 0, "Token already payed");
        item.owner = payable(caller);
        item.isRejected = false;
        item.sold = true;
        _saveMarketItem(item);
        _setTokenIdToMarket(item.tokenId, itemId, false);
        emit MarketSaleCreated(caller, itemId);
        return true;
    }

    function forceDistributeAssets(
        uint256 itemId,
        uint256 comission,
        uint256 shareMinter,
        bool isPremium
    ) external whenNotStopped onlyOwner returns (bool) {
        require(itemId > 0 && itemId <= _itemIds, "Market item not exist");
        MarketItem memory item = fetchSpecificMarketItem(itemId);
        require(item.isResolved, "Payment has been resolved");
        require(!item.isRejected, "Payment has been rejected");
        item.commission = comission;
        item.isPremium = isPremium;
        _saveMarketItem(item);
        _setTokenIdToMarket(item.tokenId, itemId, true);
        _distributeAssets(itemId, shareMinter);
        emit AssetsForciblyDistributed(itemId);
        return true;
    }

    function initialize(address market) external whenNotStopped onlyOwner returns (bool) {
        require(!_initialized, "Already initialized");
        require(market != address(0), "Market is zero address");
        IMarket marketContract = IMarket(market);
        require(address(marketContract.toMarket()) == address(this), "Migration not for this contract");
        _fromMarket = marketContract;
        _itemIds = marketContract.itemIds();
        _lastItemId = _itemIds;
        _nftContract.unpause();
        _initialized = true;
        return _initialized;
    }

    function migrate(address market) external onlyOwner returns (bool) {
        address zero = address(0);
        address this_ = address(this);
        require(market != zero, "Market is zero address");
        require(address(_toMarket) == zero, "Contract already migrated");
        _stopped = true;
        _nftContract.pause();
        _nftContract.setMarket(market);
        uint256 balanceLinkToken = _linkToken.balanceOf(this_);
        if (this_.balance > 0) payable(market).transfer(this_.balance);
        if (balanceLinkToken > 0) _linkToken.transfer(market, balanceLinkToken);
        _toMarket = IMarket(market);
        _lastItemId = _lastItemId == 0 ? 0 : _itemIds;
        return true;
    }

    function rejectDeal(uint256 itemId, uint256 fee) external whenNotStopped onlyOwner returns (bool) {
        require(_itemIds >= itemId, "Market item not exist");
        MarketItem memory item = fetchSpecificMarketItem(itemId);
        uint256 price = item.price;
        require(!item.isResolved, "Payment has been resolved");
        require(!item.isRejected, "Payment has been rejected");
        require(!item.isDistributeAssets, "Payment has been distributed");
        require(item.sold, "Market item not sold");
        require(price > fee, "Too large fee");
        uint256 refundValue = price - fee;
        item.owner.transfer(refundValue);
        payable(_nupayWalletAddress).transfer(fee);
        item.owner = payable(address(0));
        item.isRejected = true;
        _saveMarketItem(item);
        _setTokenIdToMarket(item.tokenId, itemId, true);
        emit DealRejected(itemId);
        return true;
    }

    function resolveDeal(
        uint256 tokenId,
        address sender,
        address recipient
    ) external whenNotStopped returns (bool) {
        require(msg.sender == address(_nftContract), "Invalid sender");
        uint256 itemId = idTokenToMarket(tokenId);
        MarketItem memory item = fetchSpecificMarketItem(itemId);
        if (item.seller != sender || item.owner != recipient || itemId == 0) return false;
        require(!item.isResolved, "Payment has been resolved");
        _doRequest(_urlRequest.concatStrUint(tokenId), itemId);
        item.isResolved = true;
        _saveMarketItem(item);
        emit DealResolved(itemId);
        return true;
    }

    function setFeeOracle(uint256 fee) external onlyOwner returns (bool) {
        _feeOracle = fee;
        return true;
    }

    function setNftContract(address nft) external onlyOwner returns (bool) {
        _nftContract = INFT(nft);
        return true;
    }

    function setNupayWalletAddress(address nupayWallet) external onlyOwner returns (bool) {
        _nupayWalletAddress = nupayWallet;
        return true;
    }

    function setOracle(address oracleContract, bytes32 jobId) external onlyOwner returns (bool) {
        _oracle = oracleContract;
        _jobId = jobId;
        return true;
    }

    function setUrlRequest(string memory url) external onlyOwner returns (bool) {
        _urlRequest = url;
        return true;
    }

    function saveMarketItem(MarketItem memory item) external returns (bool) {
        require(msg.sender == address(_toMarket), "Invalid sender");
        _saveMarketItem(item);
        return true;
    }

    function setTokenIdToMarket(
        uint256 tokenId,
        uint256 itemId,
        bool remove
    ) external returns (bool) {
        require(msg.sender == address(_toMarket), "Invalid sender");
        _setTokenIdToMarket(tokenId, itemId, remove);
        return true;
    }

    function fulfill(bytes32 requestId, bytes32 commission)
        public
        whenNotStopped
        recordChainlinkFulfillment(requestId)
    {
        uint256 itemId = _reqIds[requestId];
        MarketItem memory item = fetchSpecificMarketItem(itemId);
        require(_itemIds >= itemId, "Market item not exist");
        require(!item.isRejected, "Payment has been rejected");
        string[] memory splitArr = bytes32ToString(commission).split("|");
        uint256 minterShare = splitArr[2].st2num();
        item.commission = splitArr[0].st2num();
        if (splitArr[1].compareTo("premium")) {
            item.isPremium = true;
        } else {
            item.isPremium = false;
        }
        _saveMarketItem(item);
        _distributeAssets(itemId, minterShare);
    }

    function _distributeAssets(uint256 itemId, uint256 feeMinter) private returns (bool) {
        MarketItem memory item = fetchSpecificMarketItem(itemId);
        require(!item.isDistributeAssets, "Assets already allocated");
        require(feeMinter < HUNDRED_PERCENT, "Fee exceeded");
        require(item.commission < HUNDRED_PERCENT, "Fee exceeded");
        address minter = _nftContract.creatorToken(item.tokenId);
        uint256 totalSent = item.price;
        uint256 commission = item.commission;
        uint256 minterShare = (totalSent * feeMinter) / HUNDRED_PERCENT;
        uint256 ourShare = 0;
        uint256 sellerShare = 0;
        if (item.isPremium == true) {
            ourShare = totalSent - minterShare;
        } else {
            ourShare = (totalSent * commission) / HUNDRED_PERCENT;
            sellerShare = totalSent - ourShare - minterShare;
            item.seller.transfer(sellerShare);
        }
        if (ourShare > 0) payable(_nupayWalletAddress).transfer(ourShare);
        if (minterShare > 0) payable(minter).transfer(minterShare);
        item.isDistributeAssets = true;
        _saveMarketItem(item);
        _setTokenIdToMarket(item.tokenId, itemId, true);
        emit AssetsDistributed(itemId);
        return true;
    }

    function _doRequest(string memory url, uint256 itemId) private returns (bool) {
        Chainlink.Request memory req = buildChainlinkRequest(_jobId, address(this), this.fulfill.selector);
        req.add("get", url);
        req.add("path", "result");
        bytes32 requestId = sendChainlinkRequestTo(_oracle, req, _feeOracle);
        _reqIds[requestId] = itemId;
        return true;
    }

    function _saveMarketItem(MarketItem memory item) private returns (bool) {
        if (item.itemId > 0 && item.itemId <= _lastItemId) {
            _fromMarket.saveMarketItem(item);
        } else {
            _idToMarketItem[item.itemId] = item;
        }
        return true;
    }

    function _setTokenIdToMarket(
        uint256 tokenId,
        uint256 itemId,
        bool remove
    ) private returns (bool) {
        if (itemId > 0 && itemId <= _lastItemId) {
            _fromMarket.setTokenIdToMarket(tokenId, itemId, remove);
        } else if (remove) {
            delete _idTokenToMarket[tokenId];
        } else {
            _idTokenToMarket[tokenId] = itemId;
        }
        return true;
    }

    modifier whenNotStopped() {
        require(!_stopped, "Contract stopped");
        _;
    }

    modifier whenStopped() {
        require(_stopped, "Contract not stopped");
        _;
    }
}