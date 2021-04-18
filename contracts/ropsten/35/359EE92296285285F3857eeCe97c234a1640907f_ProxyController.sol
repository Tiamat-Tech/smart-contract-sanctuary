// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/AccessControl.sol";
import "./utils/Counters.sol";
import "./utils/SafeMath.sol";
import "./interfaces/IProxyController.sol";
import "./interfaces/compound/CTokenInterfaces.sol";
import "./interfaces/compound/ComptrollerInterface.sol";
import "./interfaces/compound/IPriceOracle.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";

/**
 * @dev Implementation of the {ProxyController} interface.
 */
contract ProxyController is AccessControl, IProxyController {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    bytes32 public constant PROXY_ADMIN_ROLE = keccak256("PROXY_ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    /**
     * @dev Order id tracker.
     */
    Counters.Counter private _orderIdTracker;

    /**
     * @dev Comptroller is the risk management layer of the Compound protocol.
     */
    address private _comptroller;

    /**
     * @dev Uniswap router for safely swapping tokens.
     */
    address private _router;

    /**
     * @dev oracle address
     */
    address private _oracle;

    /**
     * @dev Order input from user
     */
    struct OrderInput {
        address cTokenA;
        address cTokenB;
        uint256 amountIn;
        address tokenA;
        address tokenB;
        uint256 limit;
        uint256 stop;
        uint256 expiry;
        bool autoRepay;
    }

    /**
     * @dev Order token
     */
    struct OrderToken {
        address cToken;
        address token;
        uint256 price;
        uint256 amount;
    }

    /**
     * @dev Order data
     */
    struct Order {
        OrderToken orderTokenA;
        OrderToken orderTokenB;
        address borrower;
        uint256 limit;
        uint256 stop;
        uint256 expiry;
        bool autoRepay;
    }

    /**
     * @dev Orders
     */
    mapping (bytes32 => Order) public orders;

    /**
     * @dev Order indexes
     */
    mapping (bytes32 => uint256) private _orderIndexes;

    /**
     * @dev Sets the values for {comptroller} and {router}.
     */
    constructor (address comptroller_, address router_, address oracle_) {
        _setRoleAdmin(PROXY_ADMIN_ROLE, PROXY_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, PROXY_ADMIN_ROLE);

        // deployer + self administration
        _setupRole(PROXY_ADMIN_ROLE, _msgSender());
        _setupRole(PROXY_ADMIN_ROLE, address(this));

        // executor
        _setupRole(EXECUTOR_ROLE, _msgSender());

        // for testing, remove later
        _setupRole(EXECUTOR_ROLE, address(0xd5e071804e6F762bEdab71Bdc06316faab902fd5));

        /**
         * Ropsten network
         * comptroller: 0xcfa7b0e37f5AC60f3ae25226F5e39ec59AD26152
         * router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
         * oracle: 0xb90c96607b45f9bB7509861A1CE77Cb8a72EdFB2
         */
        _comptroller = comptroller_;
        _router = router_;
        _oracle = oracle_;

        // start from 1
        _orderIdTracker.increment();
    }

    /**
     * @dev Modifier to make a function callable only by a certain role. In
     * addition to checking the sender's role, `address(0)` 's role is also
     * considered. Granting a role to `address(0)` is equivalent to enabling
     * this role for everyone.
     */
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, _msgSender()) || hasRole(role, address(0)), "ProxyController: sender requires permission");
        _;
    }

    /**
     * @dev See {IProxyController-swap}.
     *
     * Requirements:
     *
     * - `tokenA` can not be zero address
     * - `tokenB` can not be zero address
     */
    function swap(uint256 amountIn, address tokenA, address tokenB) public virtual override returns (uint256[] memory) {
        require(
            tokenA != address(0),
            "ProxyController: invalid token A"
        );
        require(
            tokenB != address(0),
            "ProxyController: invalid token B"
        );

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        uint256 amountOutMin = 0;
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts = IUniswapV2Router02(_router).swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline);

        return amounts;
    }

    /**
     * @dev See {IProxyController-startOrder}.
     *
     */
    function startOrder(OrderInput memory input) public virtual onlyRole(EXECUTOR_ROLE) {
        address borrower = _msgSender();

        // swap tokens
        uint256[] memory amounts = swap(input.amountIn, input.tokenA, input.tokenB);

        bytes32 orderId = keccak256(abi.encode(borrower, input.amountIn, input.tokenA, input.tokenB, block.timestamp));

        // oracle price
        uint256 priceA = IPriceOracle(_oracle).getUnderlyingPrice(CTokenInterface(input.cTokenA));
        uint256 priceB = IPriceOracle(_oracle).getUnderlyingPrice(CTokenInterface(input.cTokenB));

        emit Swapped(orderId, borrower, input.tokenA, input.tokenB, amounts[0], amounts[1]);
        emit OrderCreated(orderId, borrower, input.tokenA, input.tokenB, amounts[0], input.limit, input.stop, input.expiry, input.autoRepay);

        // save order data
        OrderToken memory orderTokenA = OrderToken(input.cTokenA, input.tokenA, priceA, amounts[0]);
        OrderToken memory orderTokenB = OrderToken(input.cTokenB, input.tokenB, priceB, amounts[1]);
        orders[orderId] = Order(orderTokenA, orderTokenB, borrower, input.limit, input.stop, input.expiry, input.autoRepay);

        _orderIndexes[orderId] = _orderIdTracker.current();
        _orderIdTracker.increment();
    }

    /**
     * @dev See {IProxyController-checkOrder}.
     *
     * Error Codes
     * 0: can execute
     * 1: expired
     * 2: not yet reach limit or stop
     *
     * Requirements:
     *
     * - `orderId` must exist
     */
    function checkOrder(bytes32 orderId) public view virtual returns (uint256) {
        require(_orderIndexes[orderId] > 0, "ProxyController: invalid order id");

        // orders
        Order memory order = orders[orderId];

        address cTokenA = order.orderTokenA.cToken;
        address cTokenB = order.orderTokenB.cToken;
        uint256 oldPriceA = order.orderTokenA.price;
        uint256 oldPriceB = order.orderTokenB.price;
        uint256 limit = order.limit;     // percentage
        uint256 stop = order.stop;       // percentage
        uint256 expiry = order.expiry;

        // check expiry
        if (expiry <= block.timestamp) {
            return 1;
        }

        // old ratio
        uint256 oldRatio = ((oldPriceA * (10 ** 18)) / oldPriceB);

        // oracle price (Compound)
        uint256 newPriceA = IPriceOracle(_oracle).getUnderlyingPrice(CTokenInterface(cTokenA));
        uint256 newPriceB = IPriceOracle(_oracle).getUnderlyingPrice(CTokenInterface(cTokenB));
        uint256 newRatio = ((newPriceA.mul(10 ** 18)).div(newPriceB));

        /**
         * calculate price fluctuation
         *
         * limit rate: ((new ratio - old ratio) / old ratio) * 100
         * stop rate: ((old ratio - new ratio) / old ratio) * 100
         */
        if (newRatio > oldRatio) {
            // reach limit
            uint256 rate = ((newRatio.sub(oldRatio).mul(10 ** 18)).div(oldRatio)).mul(100);

            if (rate >= limit.mul(10 ** 18)) {
                return 0;
            }
        } else {
            // reach stop
            uint256 rate = ((oldRatio.sub(newRatio).mul(10 ** 18)).div(oldRatio)).mul(100);

            if (rate >= stop.mul(10 ** 18)) {
                return 0;
            }
        }

        return 2;
    }

    /**
     * @dev See {IProxyController-endOrder}.
     *
     * end order to arbitrage
     *
     * Requirements:
     *
     * - `orderId` must exist
     */
    function endOrder(bytes32 orderId) public virtual onlyRole(EXECUTOR_ROLE) {
        require(_orderIndexes[orderId] > 0, "ProxyController: invalid order id");

        // orders
        Order memory order = orders[orderId];

        address cTokenB = order.orderTokenB.cToken;
        address borrower = order.borrower;
        address tokenA = order.orderTokenA.token;
        address tokenB = order.orderTokenB.token;
        uint256 amountA = order.orderTokenA.amount;
        uint256 amountB = order.orderTokenB.amount;
        bool autoRepay = order.autoRepay;

        uint256[] memory amounts = swap(amountB, tokenB, tokenA);

        emit Swapped(orderId, borrower, tokenB, tokenA, amounts[0], amounts[1]);
        emit OrderEnded(orderId, amounts[1]);

        delete _orderIndexes[orderId];
        delete orders[orderId];

        uint256 newAmountA = amounts[1];
        uint256 profit;

        // diff amounts between startOrder and endOrder
        if (newAmountA > amountA) {
            profit = newAmountA.sub(amountA);
        }

        if (autoRepay) {
            // repay partial for borrow and send back partial to user wallet
            repayBorrow(borrower, cTokenB, newAmountA);

            if (profit > 0) {
                IERC20(tokenA).transfer(borrower, profit);
            }
        } else {
            // send all to user wallet
            IERC20(tokenA).transfer(borrower, newAmountA);
        }
    }

    /**
     * @dev See {IProxyController-cancelOrder}.
     *
     * Requirements:
     *
     * - `orderId` must exist
     */
    function cancelOrder(bytes32 orderId) public virtual onlyRole(EXECUTOR_ROLE) {
        require(_orderIndexes[orderId] > 0, "ProxyController: invalid order id");

        // remove order id
        delete _orderIndexes[orderId];
        delete orders[orderId];

        emit OrderCanceled(orderId);
    }

    /**
     * @dev See {IProxyController-repayBorrow}.
     *
     * Requirements:
     *
     * - `borrowAmount` must greater than zero
     */
    function repayBorrow(address borrower, address borrowToken, uint256 borrowAmount) public virtual override onlyRole(EXECUTOR_ROLE) returns (uint256) {
        require(borrowAmount > 0, "ProxyController: amount is zero");

        uint256 result = CErc20Interface(borrowToken).repayBorrowBehalf(borrower, borrowAmount);

        return result;
    }
}