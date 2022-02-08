// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/Bytes32Library.sol";
import "./libraries/StringLibrary.sol";

import "./interfaces/ITradePairs.sol";
import "./interfaces/IOrderBooks.sol";
import "./interfaces/IPortfolio.sol";
import "./interfaces/IDexManager.sol";


contract TradePairs is Ownable, ITradePairs , ReentrancyGuard {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using StringLibrary for string;
    using Bytes32Library for bytes32;

    // reference to OrderBooks contract (one sell or buy book)
    IOrderBooks private orderBooks;
    IPortfolio private portfolio;
    IDexManager private dexManager;

    // a dynamic array of trade pairs added to TradePairs contract
    bytes32[] private tradePairsArray;

    // order counter to build a unique handle for each new order
    uint private orderCounter;

    // mapping data structure for all trade pairs
    mapping (bytes32 => TradePair) private tradePairMap;
    // mapping  for allowed order types for a TradePair
    mapping (bytes32 => EnumerableSetUpgradeable.UintSet) private allowedOrderTypes;
    // mapping structure for all orders
    mapping (bytes32 => Order) private orderMap;


    event Executed(bytes32 indexed pair, uint price, uint quantity, bytes32 maker, bytes32 taker, uint feeMaker, uint feeTaker, bool feeMakerBase);
    event OrderStatusChanged(address indexed traderAddress, bytes32 indexed pair, bytes32 id,  uint price, uint totalamount, uint quantity,
        Side side, Type1 type1, Status status, uint quantityfilled, uint totalfee);
    event TradePairsInit(address orderBookAddress, address portofolioAddress, address tradePairsAddress);
    event TradePairAdded(bytes32 indexed pair, address baseToken, address quoteToken);
    event ParameterUpdated(bytes32 indexed pair, string param, uint oldValue, uint newValue);
    event UpdateOrder(bytes32 orderId);
    function addTradePair(bytes32[] memory _assets, address[] memory _addresses, uint[] memory _fees, uint[] memory _amounts, bool _isActive) public override {
        bytes32 _tradePairId = _assets[0];
        require(tradePairMap[_tradePairId].baseSymbol == '', "You already added this trade pair");
        bytes32 _buyBookId = string(abi.encodePacked(_tradePairId.bytes32ToString(), '-BUYBOOK')).stringToBytes32();
        bytes32 _sellBookId = string(abi.encodePacked(_tradePairId.bytes32ToString(), '-SELLBOOK')).stringToBytes32();
        tradePairMap[_tradePairId].baseSymbol = _assets[1];
        tradePairMap[_tradePairId].baseAddress = _addresses[0];
        tradePairMap[_tradePairId].baseDecimals = _amounts[0];
        tradePairMap[_tradePairId].baseDisplayDecimals = _amounts[1];
        tradePairMap[_tradePairId].quoteSymbol = _assets[2];
        tradePairMap[_tradePairId].quoteAddress = _addresses[1];
        tradePairMap[_tradePairId].quoteDecimals = _amounts[2];
        tradePairMap[_tradePairId].quoteDisplayDecimals = _amounts[3];
        tradePairMap[_tradePairId].minTradeAmount = _amounts[4];
        tradePairMap[_tradePairId].maxTradeAmount = _amounts[5];
        tradePairMap[_tradePairId].buyBookId = _buyBookId;
        tradePairMap[_tradePairId].sellBookId = _sellBookId;
        tradePairMap[_tradePairId].makerFee = _fees[0]; // makerFee=10 (0.10% = 10/10000)
        tradePairMap[_tradePairId].takerFee = _fees[1]; // takerFee=20 (0.20% = 20/10000)
        tradePairMap[_tradePairId].allowedSlippagePercent = _amounts[6]; // allowedSlippagePercent=20 (20% = 20/
        tradePairMap[_tradePairId].isActive = _isActive;
        EnumerableSetUpgradeable.UintSet storage enumSet = allowedOrderTypes[_tradePairId];
        tradePairMap[_tradePairId].pairPaused = false;       // addOrder is not paused by default
        tradePairMap[_tradePairId].addOrderPaused = false;   // pair is not paused by default
        enumSet.add(uint(Type1.LIMIT));   // LIMIT orders always allowed

        tradePairsArray.push(_tradePairId);
        emit TradePairAdded(_tradePairId, _addresses[0], _addresses[1]);
    }

    function pauseTradePair(bytes32 _tradePairId, bool _pairPaused) public override onlyOwner {
        tradePairMap[_tradePairId].pairPaused = _pairPaused;
    }

    function pauseAddOrder(bytes32 _tradePairId, bool _addOrderPaused) public override onlyOwner {
        tradePairMap[_tradePairId].addOrderPaused = _addOrderPaused;
    }

    function initialize(address _orderBooks, address _portfolio, address _dexManager) public onlyOwner {
        orderBooks = IOrderBooks(_orderBooks);
        portfolio = IPortfolio(_portfolio);
        dexManager = IDexManager(_dexManager);
        emit TradePairsInit(_orderBooks, _portfolio, _dexManager);
    }

    function getTradePairs() public override view returns (bytes32[] memory) {
        return tradePairsArray;
    }

    function getTradePairInfo(bytes32 _tradePairId) external view override returns (TradePair memory){
        return tradePairMap[_tradePairId];
    }

    function getMinTradeAmount(bytes32 _tradePairId) public override view returns (uint) {
        return tradePairMap[_tradePairId].minTradeAmount;
    }

    function setMinTradeAmount(bytes32 _tradePairId, uint256 _minTradeAmount) public override onlyOwner {
        uint oldValue = tradePairMap[_tradePairId].minTradeAmount;
        tradePairMap[_tradePairId].minTradeAmount = _minTradeAmount;
        emit ParameterUpdated(_tradePairId, "T-MINTRAMT", oldValue, _minTradeAmount);
    }


    function getMaxTradeAmount(bytes32 _tradePairId) public override view returns (uint) {
        return tradePairMap[_tradePairId].maxTradeAmount;
    }

    function setMaxTradeAmount(bytes32 _tradePairId, uint256 _maxTradeAmount) public override {
        uint oldValue = tradePairMap[_tradePairId].maxTradeAmount;
        tradePairMap[_tradePairId].maxTradeAmount = _maxTradeAmount;
        emit ParameterUpdated(_tradePairId, "T-MAXTRAMT", oldValue, _maxTradeAmount);
    }

    function addOrderType(bytes32 _tradePairId, Type1 _type) public override {
        allowedOrderTypes[_tradePairId].add(uint(_type));
        emit ParameterUpdated(_tradePairId, "T-OTYPADD", 0, uint(_type));
    }

    function removeOrderType(bytes32 _tradePairId, Type1 _type) public override onlyOwner {
        require(_type != Type1.LIMIT, "T-LONR-01");
        allowedOrderTypes[_tradePairId].remove(uint(_type));
        emit ParameterUpdated(_tradePairId, "T-OTYPREM", 0, uint(_type));
    }

    function getAllowedOrderTypes(bytes32 _tradePairId) public view returns (uint[] memory) {
        uint size = allowedOrderTypes[_tradePairId].length();
        uint[] memory allowed = new uint[](size);
        for (uint i=0; i<size; i++) {
            allowed[i] = allowedOrderTypes[_tradePairId].at(i);
        }
        return allowed;
    }

    function setDisplayDecimals(bytes32 _tradePairId, uint256 _displayDecimals, bool _isBase) public override onlyOwner {
        uint oldValue = tradePairMap[_tradePairId].baseDisplayDecimals;
        if (_isBase) {
            tradePairMap[_tradePairId].baseDisplayDecimals = _displayDecimals;
        } else {
            oldValue = tradePairMap[_tradePairId].quoteDisplayDecimals;
            tradePairMap[_tradePairId].quoteDisplayDecimals = _displayDecimals;
        }
        emit ParameterUpdated(_tradePairId, "T-DISPDEC", oldValue, _displayDecimals);
    }

    function getDisplayDecimals(bytes32 _tradePairId, bool _isBase) public override view returns (uint256) {
        if (_isBase) {
            return tradePairMap[_tradePairId].baseDisplayDecimals;
        } else {
            return tradePairMap[_tradePairId].quoteDisplayDecimals;
        }
    }

    function getDecimals(bytes32 _tradePairId, bool _isBase) public override view returns (uint256) {
        if (_isBase) {
            return tradePairMap[_tradePairId].baseDecimals;
        } else {
            return tradePairMap[_tradePairId].quoteDecimals;
        }
    }

    function getSymbol(bytes32 _tradePairId, bool _isBase) public override view returns (bytes32) {
        if (_isBase) {
            return tradePairMap[_tradePairId].baseSymbol;
        } else {
            return tradePairMap[_tradePairId].quoteSymbol;
        }
    }

    function updateFee(bytes32 _tradePairId, uint256 _fee, ITradePairs.RateType _rateType) public override onlyOwner {
        uint oldValue = tradePairMap[_tradePairId].makerFee;
        if (_rateType == ITradePairs.RateType.MAKER) {
            tradePairMap[_tradePairId].makerFee = _fee; // (_rate/100)% = _rate/10000: _rate=10 => 0.10%
            emit ParameterUpdated(_tradePairId, "T-MAKERRATE", oldValue, _fee);
        } else if (_rateType == ITradePairs.RateType.TAKER) {
            oldValue = tradePairMap[_tradePairId].takerFee;
            tradePairMap[_tradePairId].takerFee = _fee; // (_rate/100)% = _rate/10000: _rate=20 => 0.20%
            emit ParameterUpdated(_tradePairId, "T-TAKERRATE", oldValue, _fee);
        } // Ignore the rest for now
    }

    function getMakerFee(bytes32 _tradePairId) public view override returns (uint) {
        return tradePairMap[_tradePairId].makerFee;
    }

    function getTakerFee(bytes32 _tradePairId) public view override returns (uint) {
        return tradePairMap[_tradePairId].takerFee;
    }

    function setAllowedSlippagePercent(bytes32 _tradePairId, uint256 _allowedSlippagePercent) public override onlyOwner {
        uint oldValue = tradePairMap[_tradePairId].allowedSlippagePercent;
        tradePairMap[_tradePairId].allowedSlippagePercent = _allowedSlippagePercent;
        emit ParameterUpdated(_tradePairId, "T-SLIPPAGE", oldValue, _allowedSlippagePercent);
    }

    function getAllowedSlippagePercent(bytes32 _tradePairId) public override view returns (uint256) {
        return tradePairMap[_tradePairId].allowedSlippagePercent;
    }

    function getOrder(bytes32 _orderId) public view override returns (Order memory) {
        return orderMap[_orderId];
    }

    function getOrderId() public override returns (bytes32) {
        return keccak256(abi.encodePacked(orderCounter++));
    }

    // get remaining quantity for an Order struct - cheap pure function
    function getRemainingQuantity(Order memory _order) private pure returns (uint) {
        return _order.quantity - _order.quantityFilled;
    }

    // get quote amount
    function getQuoteAmount(bytes32 _tradePairId, uint _price, uint _quantity) private view returns (uint) {
        return  (_price * _quantity) / 10 ** tradePairMap[_tradePairId].baseDecimals;
    }

    function emitStatusUpdate(bytes32 _tradePairId, bytes32 _orderId) private {
        Order storage _order = orderMap[_orderId];
        emit OrderStatusChanged(_order.traderAddress, _tradePairId, _order.id,
            _order.price, _order.totalAmount, _order.quantity,
            _order.side, _order.type1, _order.status, _order.quantityFilled,
            _order.totalFee);
    }


    // Used to Round Down the fees to the display decimals to avoid dust
    function floor(uint a, uint m) pure private returns (uint256) {
        return (a / 10 ** m) * 10**m;
    }

    function decimalsOk(uint value, uint decimals, uint displayDecimals) public pure returns (bool) {
        return ((value % 10 ** decimals) % 10 ** (decimals - displayDecimals)) == 0;
    }

    // FRONTEND ENTRY FUNCTION TO CALL TO ADD ORDER
    function addOrder(bytes32 _tradePairId, uint _price, uint _quantity, Side _side, Type1 _type1) public override nonReentrant {
        TradePair storage _tradePair = tradePairMap[_tradePairId];
        require(!_tradePair.pairPaused, "T-PPAU-01");
        require(!_tradePair.addOrderPaused, "T-AOPA-01");
        require(_side == Side.BUY || _side == Side.SELL, "T-IVSI-01");
        require(allowedOrderTypes[_tradePairId].contains(uint(_type1)), "T-IVOT-01");
        require(decimalsOk(_quantity, _tradePair.baseDecimals, _tradePair.baseDisplayDecimals), "T-TMDQ-01");

        if (_type1 == Type1.LIMIT) {
            dexManager.addLimitOrder(_tradePairId, _price, _quantity, _side, msg.sender);
        } else if (_type1 == Type1.MARKET) {
            dexManager.addMarketOrder(_tradePairId, _quantity, _side, msg.sender);
        }
    }

    function doOrderCancel(bytes32 _tradePairId, bytes32 _orderId) private {
        TradePair storage _tradePair = tradePairMap[_tradePairId];
        Order storage _order = orderMap[_orderId];
        _order.status = Status.CANCELED;
        if (_order.side == Side.BUY) {
            orderBooks.cancelOrder(_tradePair.buyBookId, _orderId, _order.price);
            portfolio.adjustAvailable(IPortfolio.Tx.INCREASEAVAIL, _order.traderAddress, _tradePair.quoteSymbol,
                getQuoteAmount(_tradePairId, _order.price, getRemainingQuantity(_order)));
        } else {
            orderBooks.cancelOrder(_tradePair.sellBookId, _orderId, _order.price);
            portfolio.adjustAvailable(IPortfolio.Tx.INCREASEAVAIL, _order.traderAddress, _tradePair.baseSymbol, getRemainingQuantity(_order));
        }
        emitStatusUpdate(_tradePairId, _order.id);
    }

    // FRONTEND ENTRY FUNCTION TO CALL TO CANCEL ONE ORDER
    function cancelOrder(bytes32 _tradePairId, bytes32 _orderId) public override nonReentrant {
        Order storage _order = orderMap[_orderId];
        require(_order.traderAddress == msg.sender, "T-OOCC-01");
        require(_order.id != '', "T-EOID-01");
        require(!tradePairMap[_tradePairId].pairPaused, "T-PPAU-02");
        require(_order.quantityFilled < _order.quantity && (_order.status == Status.PARTIAL || _order.status== Status.NEW), "T-OAEX-01");
        doOrderCancel(_tradePairId, _order.id);
    }

    function cancelAllOrders(bytes32 _tradePairId, bytes32[] memory _orderIds) public override nonReentrant {
        require(!tradePairMap[_tradePairId].pairPaused, "T-PPAU-03");
        for (uint i = 0; i < _orderIds.length; i++) {
            Order storage _order = orderMap[_orderIds[i]];
            require(_order.traderAddress == msg.sender, "T-OOCC-02");
            if (_order.id != '' && _order.quantityFilled < _order.quantity && (_order.status == Status.PARTIAL || _order.status == Status.NEW)) {
                doOrderCancel(_tradePairId, _order.id);
            }
        }
    }

    fallback() external {}

    function getNBuyBook(bytes32 _tradePairId, uint _n) public view override returns (uint[] memory, uint[] memory) {
        // get highest (_type=1) N orders
        return orderBooks.getNOrders(tradePairMap[_tradePairId].buyBookId, _n, 1);
    }

    function getNSellBook(bytes32 _tradePairId, uint _n) public override view returns (uint[] memory, uint[] memory) {
        // get lowest (_type=0) N orders
        return orderBooks.getNOrders(tradePairMap[_tradePairId].sellBookId, _n, 0);
    }

    function updateOrder(bytes32 _orderId, Order memory _myOrder) public override {
        Order storage _order = orderMap[_orderId];
        _order.quantityFilled = _myOrder.quantityFilled;
        _order.status = _myOrder.status;
        _order.totalFee = _myOrder.totalFee;
        _order.traderAddress = _myOrder.traderAddress;
        _order.price = _myOrder.price;
        _order.quantity = _myOrder.quantity;
        _order.side = _myOrder.side;
        emit UpdateOrder(_orderId);
    }
}