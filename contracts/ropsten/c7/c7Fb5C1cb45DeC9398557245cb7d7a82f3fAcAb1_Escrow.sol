// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ReEntrancyGuard.sol";
import "./Refereed.sol";

contract Escrow is ReEntrancyGuard, Refereed {
    using SafeERC20 for IERC20;

    constructor(uint16 _orderCharge, address payable _chargeBox) {
        owner = msg.sender;
        orderCharge = _orderCharge;
        chargeBox = _chargeBox;
    }

    event OrderUpdated(
        uint256 id,
        address indexed buyer,
        address indexed seller,
        OrderState state
    );

    error InvalidState();
    error AccessNotGranted();
    error ConditionNotSupported();
    error SomethingWentWrong();

    enum OrderState {
        CREATED,
        CANCELED,
        PROCESSED,
        SETTLED
    }

    struct Order {
        address payable buyer;
        address payable seller;
        IERC20 token_address;
        uint256 amount;
        OrderState state;
    }

    address public owner;
    address payable public chargeBox;
    uint256 public orderCount;
    uint16 public orderCharge;
    mapping(uint256 => Order) public orders;

    modifier condition(bool _condition) {
        if (!_condition) revert ConditionNotSupported();
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "So sorry, you are not the owner :(");
        _;
    }

    modifier inStateOrder(OrderState _expected, uint256 _orderId) {
        if (orders[_orderId].state != _expected) revert InvalidState();
        _;
    }

    modifier onlySeller(uint256 _orderId) {
        if (orders[_orderId].seller != msg.sender) revert AccessNotGranted();
        _;
    }

    modifier onlyBuyer(uint256 _orderId) {
        if (orders[_orderId].buyer != msg.sender) revert AccessNotGranted();
        _;
    }

    function setChargeBox(address payable _chargeBox) public onlyOwner {
        chargeBox = _chargeBox;
    }

    function setChargeOrder(uint16 _orderCharge) public onlyOwner {
        orderCharge = _orderCharge;
    }

    function forceCancelOrder(uint256 _orderId)
        public
        onlyReferee
        noReentrant
        inStateOrder(OrderState.PROCESSED, _orderId)
    {
        Order storage order = orders[_orderId];
        order.state = OrderState.CANCELED;

        if (order.token_address == IERC20(address(0))) {
            order.buyer.transfer(order.amount);
        } else {
            IERC20(order.token_address).safeTransfer(order.buyer, order.amount);
        }

        emit OrderUpdated(_orderId, order.buyer, order.seller, order.state);
    }

    function forceSettleOrder(uint256 _orderId)
        public
        onlyReferee
        noReentrant
        inStateOrder(OrderState.PROCESSED, _orderId)
    {
        Order storage order = orders[_orderId];
        order.state = OrderState.SETTLED;

        if (order.token_address == IERC20(address(0))) {
            order.seller.transfer(order.amount);
        } else {
            IERC20(order.token_address).safeTransfer(
                order.seller,
                order.amount
            );
        }

        emit OrderUpdated(_orderId, order.buyer, order.seller, order.state);
    }

    function processOrder(uint256 _orderId)
        public
        onlySeller(_orderId)
        noReentrant
        inStateOrder(OrderState.CREATED, _orderId)
    {
        Order storage order = orders[_orderId];
        order.state = OrderState.PROCESSED;

        emit OrderUpdated(_orderId, order.buyer, order.seller, order.state);
    }

    function settleOrder(uint256 _orderId)
        public
        onlyBuyer(_orderId)
        noReentrant
        inStateOrder(OrderState.PROCESSED, _orderId)
    {
        Order storage order = orders[_orderId];
        order.state = OrderState.SETTLED;

        if (order.token_address == IERC20(address(0))) {
            order.seller.transfer(order.amount);
        } else {
            IERC20(order.token_address).safeTransfer(
                order.seller,
                order.amount
            );
        }

        emit OrderUpdated(_orderId, order.buyer, order.seller, order.state);
    }

    function cancelOrder(uint256 _orderId)
        public
        onlyBuyer(_orderId)
        noReentrant
        inStateOrder(OrderState.CREATED, _orderId)
    {
        Order storage order = orders[_orderId];
        order.state = OrderState.CANCELED;

        if (order.token_address == IERC20(address(0))) {
            order.buyer.transfer(order.amount);
        } else {
            IERC20(order.token_address).safeTransfer(order.buyer, order.amount);
        }

        emit OrderUpdated(_orderId, order.buyer, order.seller, order.state);
    }

    function createOrderChain(address payable _seller)
        public
        payable
        condition(msg.value > 0)
    {
        uint256 chargeAmount = (msg.value * orderCharge) / 10000;
        uint256 finalAmount = msg.value - chargeAmount;

        bool sent = chargeBox.send(chargeAmount);
        if (!sent) {
            revert SomethingWentWrong();
        }

        Order storage order = orders[orderCount];
        order.buyer = payable(msg.sender);
        order.seller = _seller;
        order.amount = finalAmount;
        order.state = OrderState.CREATED;

        emit OrderUpdated(orderCount, order.buyer, order.seller, order.state);

        orderCount++;
    }

    function createOrderToken(
        address payable _seller,
        IERC20 _token_address,
        uint256 _amount
    ) public {
        uint256 chargeAmount = (_amount * orderCharge) / 10000;
        uint256 finalAmount = _amount - chargeAmount;

        IERC20(_token_address).safeTransferFrom(
            msg.sender,
            chargeBox,
            chargeAmount
        );
        IERC20(_token_address).safeTransferFrom(
            msg.sender,
            address(this),
            finalAmount
        );

        Order storage order = orders[orderCount];
        order.buyer = payable(msg.sender);
        order.seller = _seller;
        order.token_address = _token_address;
        order.amount = finalAmount;
        order.state = OrderState.CREATED;

        emit OrderUpdated(orderCount, order.buyer, order.seller, order.state);

        orderCount++;
    }
}