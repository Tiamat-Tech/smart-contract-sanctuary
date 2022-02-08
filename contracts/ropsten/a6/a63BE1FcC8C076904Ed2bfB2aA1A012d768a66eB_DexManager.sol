// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IDexManager.sol";

import "./libraries/Bytes32Library.sol";
import "./libraries/StringLibrary.sol";
import "./DexOwner.sol";
/**
*   @author "DEXPOOL TEAM"
*   @title "The DexManager contract is the main entry point to DEXPOOL Decentralized Exchange Trading."
*
*   @dev Start up order:
*   @dev     1. Deploy contracts: Exchange, Portfolio, OrderBooks, TradePairs
*   @dev     2. Call addTradePairs on Exchange
*   @dev     3. Call setPortfolio and setTradePairs on Exchange
*   @dev     4. Change ownership of contracts as per below
*   @dev     5. Call addToken on Exchange to add supported ERC20 tokens to Portfolio
*
*   @dev "During deployment the ownerships of contracts are changed so they become as follows once DEXALOT is fully deployed:"
*   @dev "Exchange is owned by proxyAdmin."
*   @dev "Portfolio contract is owned by exchange contract."
*   @dev "TradePairs contract is owned by exchange contract."
*   @dev "OrderBooks contract is owned by TradePairs contract."
*   @dev "Only tradepairs can internally call addExecution and adjustAvailable functions."
*   @dev "Only valid trader accounts can call deposit and withdraw functions for their own accounts."
*/
contract DexManager is IDexManager, DexOwner, ReentrancyGuard {
  using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
  using SafeMath  for uint256;
  using SafeERC20 for IERC20;
  using StringLibrary for string;
  using Bytes32Library for bytes32;

  // denominator for rate calculations
  uint private constant TENK = 10000;

  function addTradePair(bytes32[] memory _assets, address[] memory _addresses, uint[] memory _fees, uint256[] memory _amounts, bool _isActive) public onlyOwner {
    if (_assets[1] != bytes32("AVAX")) {
      portfolio.addToken(_assets[1], IERC20MetadataUpgradeable(_addresses[0]));
    }
    // check if quote asset is native AVAX, if not it is ERC20 and add it
    if (_assets[2] != bytes32("AVAX")) {
      portfolio.addToken(_assets[2], IERC20MetadataUpgradeable(_addresses[1]));
    }
    tradePairs.addTradePair(_assets, _addresses, _fees, _amounts, _isActive);
  }


  event Executed(bytes32 indexed pair, uint price, uint quantity, bytes32 maker, bytes32 taker, uint feeMaker, uint feeTaker, bool feeMakerBase);
  event OrderStatusChanged(address indexed traderAddress, bytes32 indexed pair, bytes32 id,  uint price, uint totalamount, uint quantity,
    ITradePairs.Side side, ITradePairs.Type1 type1, ITradePairs.Status status, uint quantityfilled, uint totalfee);


  // get quote amount
  function getQuoteAmount(bytes32 _tradePairId, uint _price, uint _quantity) public view returns (uint) {
    return  (_price * _quantity) / 10 ** tradePairs.getTradePairInfo(_tradePairId).baseDecimals;
  }


  function emitStatusUpdate(bytes32 _tradePairId, bytes32 _orderId) private {
    ITradePairs.Order memory _order = tradePairs.getOrder(_orderId);
    emit OrderStatusChanged(_order.traderAddress, _tradePairId, _order.id,
      _order.price, _order.totalAmount, _order.quantity,
      _order.side, _order.type1, _order.status, _order.quantityFilled,
      _order.totalFee);
  }

  function matchSellBook(bytes32 _tradePairId, ITradePairs.Order memory takerOrder) private returns (uint) {
    bytes32 sellBookId = tradePairs.getTradePairInfo(_tradePairId).sellBookId;
    uint price = orderBooks.first(sellBookId);
    bytes32 head = orderBooks.getHead(sellBookId, price);
    ITradePairs.Order memory makerOrder;
    uint quantity;
    // Don't need price > 0 check as sellBook.getHead(price) != '' takes care of it
    while ( getRemainingQuantity(takerOrder) > 0 && head != '' && takerOrder.price >= price) {
      makerOrder = tradePairs.getOrder(head);
      quantity = orderBooks.matchTrade(sellBookId, price, getRemainingQuantity(takerOrder), getRemainingQuantity(makerOrder));
      addExecution(_tradePairId, makerOrder, takerOrder, price, quantity); // this makes a state change to Order Map
      takerOrder.quantityFilled += quantity;
      price = orderBooks.first(sellBookId);
      head = orderBooks.getHead(sellBookId, price);
    }
    return getRemainingQuantity(takerOrder);
  }

  function handleExecution(bytes32 _tradePairId, bytes32 _orderId, uint _price, uint _quantity, uint _rate) public returns (uint) {
    ITradePairs.TradePair memory _tradePair = tradePairs.getTradePairInfo(_tradePairId);
    ITradePairs.Order memory _order = tradePairs.getOrder(_orderId);
    require(_order.status != ITradePairs.Status.CANCELED, "T-OACA-01");
    _order.quantityFilled += _quantity;
    require(_order.quantityFilled <= _order.quantity, "T-CQFA-01");
    _order.status = _order.quantity == _order.quantityFilled ? ITradePairs.Status.FILLED : ITradePairs.Status.PARTIAL;
    uint amount = getQuoteAmount(_tradePairId, _price, _quantity);
    _order.totalAmount += amount;
    // Rounding Down the fee based on display decimals to avoid DUST
    uint lastFeeRounded = _order.side == ITradePairs.Side.BUY ?
    floor(_quantity * _rate / TENK, _tradePair.baseDecimals - _tradePair.baseDisplayDecimals) :
    floor(amount * _rate / TENK, _tradePair.quoteDecimals - _tradePair.quoteDisplayDecimals);
    _order.totalFee += lastFeeRounded;
    tradePairs.updateOrder(_orderId, _order);
    return lastFeeRounded;
  }

  function addExecution(bytes32 _tradePairId, ITradePairs.Order memory _marketOrder, ITradePairs.Order memory _takerOrder, uint _price, uint _quantity) private {
    ITradePairs.TradePair memory _tradePair = tradePairs.getTradePairInfo(_tradePairId);
    // fill the maker first so it is out of the book quickly
    uint mlastFee = handleExecution(_tradePairId, _marketOrder.id, _price, _quantity, _tradePair.makerFee);
    uint tlastFee = handleExecution(_tradePairId, _takerOrder.id, _price, _quantity, _tradePair.takerFee);
    portfolio.addExecution(
      _marketOrder,
      _takerOrder.traderAddress,
      _tradePair.baseSymbol,
      _tradePair.quoteSymbol,
      _quantity,
      getQuoteAmount(_tradePairId, _price, _quantity),
      mlastFee,
      tlastFee);
    emit Executed(_tradePairId, _price, _quantity, _marketOrder.id, _takerOrder.id, mlastFee, tlastFee, _marketOrder.side == ITradePairs.Side.BUY ? true : false);

    emitStatusUpdate(_tradePairId, _marketOrder.id); // EMIT maker order's status update
  }

  // get remaining quantity for an Order struct - cheap pure function
  function getRemainingQuantity(ITradePairs.Order memory _order) public pure returns (uint) {
    return _order.quantity - _order.quantityFilled;
  }

  function matchBuyBook(bytes32 _tradePairId, ITradePairs.Order memory takerOrder) private returns (uint) {
    bytes32 buyBookId = tradePairs.getTradePairInfo(_tradePairId).buyBookId;
    uint price = orderBooks.last(buyBookId);
    bytes32 head = orderBooks.getHead(buyBookId, price);
    ITradePairs.Order memory makerOrder;
    uint quantity;
    //Don't need price > 0 check as buyBook.getHead(price) != '' takes care of it
    while (getRemainingQuantity(takerOrder) > 0 && head != '' && takerOrder.price <=  price) {
      makerOrder = tradePairs.getOrder(head);
      quantity = orderBooks.matchTrade(buyBookId, price, getRemainingQuantity(takerOrder), getRemainingQuantity(makerOrder));
      addExecution(_tradePairId, makerOrder, takerOrder, price, quantity); // this makes a state change to Order Map
      takerOrder.quantityFilled += quantity;  // locally keep track of Qty remaining
      price = orderBooks.last(buyBookId);
      head = orderBooks.getHead(buyBookId, price);
    }
    return getRemainingQuantity(takerOrder);
  }

  // Used to Round Down the fees to the display decimals to avoid dust
  function floor(uint a, uint m) pure private returns (uint256) {
    return (a / 10 ** m) * 10**m;
  }

  function decimalsOk(uint value, uint decimals, uint displayDecimals) private pure returns (bool) {
    return (value - (value - ((value % 10 ** decimals) % 10 ** (decimals - displayDecimals)))) == 0;
  }


  function addLimitOrder(
    bytes32 _tradePairId,
    uint _price,
    uint _quantity,
    ITradePairs.Side _side,
    address _traderAddress
    ) public override {
    ITradePairs.TradePair memory _tradePair = tradePairs.getTradePairInfo(_tradePairId);
    require(decimalsOk(_price, _tradePair.quoteDecimals, _tradePair.quoteDisplayDecimals), "T-TMDP-01");
    uint tradeAmnt = (_price * _quantity) / (10 ** _tradePair.baseDecimals);
    require(tradeAmnt >= _tradePair.minTradeAmount, "T-LTMT-02");
    require(tradeAmnt <= _tradePair.maxTradeAmount, "T-MTMT-02");

    bytes32 orderId = tradePairs.getOrderId();
    ITradePairs.Order memory _order = tradePairs.getOrder(orderId);
    _order.id = orderId;
    _order.traderAddress = _traderAddress;
    _order.price = _price;
    _order.quantity = _quantity;
    _order.side = _side;
    _order.type1 = ITradePairs.Type1.LIMIT;

    uint takerRemainingQuantity;
    if (_side == ITradePairs.Side.BUY) {
      takerRemainingQuantity = matchSellBook(_tradePairId, _order);
      if (takerRemainingQuantity > 0) {
        orderBooks.addOrder(_tradePair.buyBookId, _order.id, _order.price);
        portfolio.adjustAvailable(IPortfolio.Tx.DECREASEAVAIL, _order.traderAddress, _tradePair.quoteSymbol,
          getQuoteAmount(_tradePairId, _price, takerRemainingQuantity));
      }
    } else {  // == Order.Side.SELL
      takerRemainingQuantity = matchBuyBook(_tradePairId, _order);
      if (takerRemainingQuantity > 0) {
        orderBooks.addOrder(_tradePair.sellBookId, _order.id, _order.price);
        portfolio.adjustAvailable(IPortfolio.Tx.DECREASEAVAIL, _order.traderAddress, _tradePair.baseSymbol, takerRemainingQuantity);
      }
    }
    emitStatusUpdate(_tradePairId, _order.id);  // EMIT order status. if no fills, the status will be NEW, if any fills status will be either PARTIAL or FILLED
  }

  function addMarketOrder(
    bytes32 _tradePairId,
    uint _quantity,
    ITradePairs.Side _side,
    address _traderAddress) public override {
    ITradePairs.TradePair memory _tradePair = tradePairs.getTradePairInfo(_tradePairId);
    uint marketPrice;
    uint worstPrice; // Market Orders will be filled up to allowedSlippagePercent from the marketPrice to protect the trader, the remaining qty gets unsolicited cancel
    bytes32 bookId;
    if (_side == ITradePairs.Side.BUY) {
      bookId = _tradePair.sellBookId;
      marketPrice = orderBooks.first(bookId);
      worstPrice = marketPrice * ( 100 + _tradePair.allowedSlippagePercent) / 100;
    } else {
      bookId = _tradePair.buyBookId;
      marketPrice = orderBooks.last(bookId);
      worstPrice = marketPrice * ( 100 - _tradePair.allowedSlippagePercent) / 100;
    }

    // dont need digit check here as it is taken from the book
    uint tradeAmnt = (marketPrice * _quantity) / (100 ** _tradePair.baseDecimals);
    // a market order will be rejected here if there is nothing in the book because marketPrice will be 0_tradePair
    require(tradeAmnt >= _tradePair.minTradeAmount, "T-LIMIT-01");
    require(tradeAmnt <= _tradePair.maxTradeAmount, "T-MINT-01");

    bytes32 orderId = tradePairs.getOrderId();
    ITradePairs.Order memory _order = tradePairs.getOrder(orderId);
    _order.id = orderId;
    _order.traderAddress = _traderAddress;
    _order.price = worstPrice;
    _order.quantity = _quantity;
    _order.side = _side;

    uint takerRemainingQuantity;
    if (_side == ITradePairs.Side.BUY) {
      takerRemainingQuantity= matchSellBook(_tradePairId, _order);
    } else {  // == Order.Side.SELL
      takerRemainingQuantity= matchBuyBook(_tradePairId, _order);
    }

    if (!orderBooks.orderListExists(bookId, worstPrice)
    && takerRemainingQuantity > 0) {
      // IF the Market Order fills all the way to the worst price, it gets unsoliticted cancel for the remaining amount.
      _order.status = ITradePairs.Status.CANCELED;
    }
    _order.price = 0; //Reset the market order price back to 0
    tradePairs.updateOrder(orderId, _order);
    emitStatusUpdate(_tradePairId, _order.id);  // EMIT taker(potential) order status. if no fills, the status will be NEW, if not status will be either PARTIAL or FILLED
  }
}