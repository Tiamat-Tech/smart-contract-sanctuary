// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./libraries/SlidingWindowLedger.sol";


contract SlidingWindowLedger is AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;
    using SlidingWindowLedgerLibrary for SlidingWindowLedgerLibrary.SlidingWindow;

    // role hash 0x7b92c0c7fdcf766fb7ab1ec799b8a5d63ffbb8f32562df76cfe6f15236646b1e
    bytes32 constant public LEDGER_MANAGER_ROLE = keccak256("LEDGER_MANAGER_ROLE");

    // Events emit when a new order is created
    event OrderAdded(uint256 indexed orderId, address askAsset, address offerAsset, uint256 amount, address owner);
    // Events emit when existing order is removed
    event OrderRemoved(uint256 indexed orderId);

    // Contains currently known fulfillment windows.
    EnumerableSet.UintSet internal windows;
    // Contains available orders lengths.
    EnumerableSet.UintSet internal availableOrderLengths;

    // Order library
    SlidingWindowLedgerLibrary.SlidingWindow internal orders;

    // Fulfilment configuration
    uint256 public fulfilmentPrecision;
    uint256 public fulfilmentShift;

    // Id of the last created order
    uint256 internal orderId;

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _;
    }

    modifier onlyManager() {
        _checkRole(LEDGER_MANAGER_ROLE, msg.sender);
        _;
    }

    constructor (uint256 fulfilmentPrecision_, uint256 fulfilmentShift_, uint256[] memory orderLengths_) {
        fulfilmentPrecision = fulfilmentPrecision_;
        fulfilmentShift = fulfilmentShift_;
        for (uint256 i = 0; i < orderLengths_.length; i++) {
            // slither-disable-next-line unused-return
            availableOrderLengths.add(orderLengths_[i]);
        }
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
    * @dev Sets config of sliding windows.
     *
     * Requirements:
     *
     * - `fulfilmentShift_` must be strictly less than `fulfilmentPrecision_`.
     */
    function setFulfillmentConfig(uint256 fulfilmentPrecision_, uint256 fulfilmentShift_) external onlyAdmin {
        // solhint-disable-next-line reason-string
        require(fulfilmentPrecision_ > fulfilmentShift_, "Precision must be greater than shift");
        fulfilmentPrecision = fulfilmentPrecision_;
        fulfilmentShift = fulfilmentShift_;
    }

    /**
    * @dev Adds available order lengths.
     *
     * Requirements:
     *
     * - any of `orderLengths` must be not added yet.
     */
    function addOrderLengths(uint256[] memory orderLengths) external onlyAdmin {
        for (uint256 i = 0; i < orderLengths.length; i++) {
            require(availableOrderLengths.add(orderLengths[i]), "Order length already added");
        }
    }

    /**
    * @dev Remove available order lengths.
     *
     * Requirements:
     *
     * - any of `orderLengths` must be present.
     */
    function removeOrderLengths(uint256[] memory orderLengths) external onlyAdmin {
        for (uint256 i = 0; i < orderLengths.length; i++) {
            require(availableOrderLengths.remove(orderLengths[i]), "Order length not available");
        }
    }

    /**
    * @dev Returns possible order lengths.
     */
    function getOrderLengths() external view returns(uint256[] memory) {
        return availableOrderLengths.values();
    }

    /**
    * @dev Calculates sliding window based on settings and order length.
     */
    function _calculateWindow(uint256 endsInSec) internal view returns(uint256) {
        // solhint-disable-next-line not-rely-on-time
        uint256 time = block.timestamp + endsInSec;
        uint256 value = ((time / fulfilmentPrecision) + 1) * fulfilmentPrecision;

        return  value + fulfilmentShift;
    }

    /**
    * @dev Returns owner of order with id `orderId_`.
     */
    function ownerOfOrder(uint256 orderId_) external view returns(address) {
        return orders.ownerOf(orderId_);
    }

    /**
    * @dev Adds a new order into the order pool.
     *
     * Requirements:
     *
     * - order duration `endsInSec` must be whitelisted.
     */
    function addOrder(LedgerTypes.OrderInfo memory orderInfo, uint256 endsInSec) external onlyManager returns(uint256) {
        require(availableOrderLengths.contains(endsInSec), "Order length is not supported.");

        uint256 window = _calculateWindow(endsInSec);

        orderId += 1;
        orderInfo.id = orderId;
        // slither-disable-next-line unused-return
        windows.add(window);

        // slither-disable-next-line unused-return
        orders.add(orderInfo, window);

        emit OrderAdded(orderId, orderInfo.askAsset, orderInfo.offerAsset, 0, msg.sender);
        return orderId;
    }

    /**
    * @dev Removes existing order from order pool.
     *
     * Requirements:
     *
     * - order exists in order pool.
     */
    function removeOrder(uint256 orderId_) external onlyManager returns(bool) {
        emit OrderRemoved(orderId_);
        return orders.remove(orderId_);
    }

    /**
    * @dev Returns order info for order with particular id `orderId_`.
     */
    function getOrder(uint256 orderId_) external view returns(LedgerTypes.OrderInfo memory) {
        return orders.get(orderId_);
    }

    /**
    * @dev Returns order end window for order with particular id `orderId_`.
     */
    function getOrderEndTime(uint256 orderId_) external view returns(uint256) {
        return orders.getEndTime(orderId_);
    }

    /**
    * @dev Returns possible window durations.
     */
    function getPossibleWindows() external view returns(uint256[] memory) {
        return windows.values();
    }

    /**
    * @dev Returns all orders in the particular window.
     */
    function getOrdersPerWindow(uint256 window) external view returns(LedgerTypes.OrderInfo[] memory) {
        uint256 len = orders.count(window);
        LedgerTypes.OrderInfo[] memory windowOrders = new LedgerTypes.OrderInfo[](len);

        for (uint256 i = 0; i < len; i++) {
            (uint256 key, LedgerTypes.OrderInfo memory value) = orders.getAt(window, i);
            assert(key != 0);
            windowOrders[i] = value;
        }

        return windowOrders;
    }
}