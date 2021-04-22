// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/AccessControl.sol";
import "./utils/Counters.sol";
import "./utils/SafeMath.sol";
import "./interfaces/IVeeProxyController.sol";
import "./interfaces/compound/CTokenInterfaces.sol";
import "./interfaces/compound/ComptrollerInterface.sol";
import "./interfaces/compound/IPriceOracle.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";

/**
 * @title  Vee's proxy Contract
 * @notice Implementation of the {VeeProxyController} interface.
 * @author Vee.Finance
 */
contract VeeProxyController is AccessControl, IVeeProxyController {    
    using SafeMath for uint256;

    bytes32 public constant PROXY_ADMIN_ROLE = keccak256("PROXY_ADMIN_ROLE");
    bytes32 public constant EXECUTOR_ROLE   =  keccak256("EXECUTOR_ROLE");

    /**
     * @dev Order id tracker.
     */
    Counters.Counter private _orderIdTracker;

    /**
     * @dev Comptroller is the risk management layer of the Compound protocol.
     */
    ComptrollerInterface public comptroller;

    /**
     * @dev Uniswap router for safely swapping tokens.
     */
    IUniswapV2Router02 public router;

    /**
     * @dev Guard variable for re-entrancy checks
     */
    bool internal _notEntered;

    /**
     * @dev Order data
     */
    struct Order {
        address orderOwner;
        address ctokenA;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        uint256 stopHighPairPrice;
        uint256 stopLowPairPrice;
        uint256 expiryDate;
        bool    autoRepay;
    }

    /**
     * @dev Orders
     */
    mapping (bytes32 => Order) public orders;


    /**
     * @dev Sets the values for {comptroller} and {router}.
     */
    constructor (address comptroller_, address router_) {
        
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

        comptroller = ComptrollerInterface(comptroller_);
        router = IUniswapV2Router02(router_);      

        _notEntered = true;
    }

    /**
     * @dev Modifier to make a function callable only by a certain role. In
     * addition to checking the sender's role, `address(0)` 's role is also
     * considered. Granting a role to `address(0)` is equivalent to enabling
     * this role for everyone.
     */
    modifier onlyRole(bytes32 role) {
        require(hasRole(role, _msgSender()) || hasRole(role, address(0)), "VeeProxyController: sender requires permission");
        _;
    }

    /*** Reentrancy Guard ***/
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }

     /**
     * @dev Sender create a stop-limit order with the below conditions.
     *
     * @param orderOwner  The address of order owner
     * @param ctokenA     The address of ctoken A
     * @param tokenA      The address of token A
     * @param tokenB      The address of token B
     * @param amountA     The token A amount
     * @param stopHighPairPrice  limit token pair price
     * @param stopLowPairPrice   stop token pair price
     * @param expiryDate   expiry date
     * @param autoRepay    if automatically repay borrow after trading
     *
     * @return Order id, 0: failure.
     */
    function createOrder(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay) external returns (bytes32){
         require(amountA != 0, "createOrder: amountA can't be zero.");
        {
            IERC20 erc20TokenA = IERC20(tokenA);
            uint256 allowance = erc20TokenA.allowance(orderOwner, address(this));
            require(allowance >= amountA);
            erc20TokenA.transferFrom(orderOwner, address(this), amountA);
        }
        
       // swap tokens
       uint256[] memory amounts = swap(tokenA, amountA, tokenB);
       bytes32 orderId = keccak256(abi.encode(orderOwner, amountA, tokenA, tokenB, block.timestamp));
    
       emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
       emit OnOrderCreated(orderId, orderOwner, tokenA, tokenB, amountA, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay);

       Order memory order = Order(orderOwner, ctokenA, tokenA, tokenB, amountA, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay);
       orders[orderId] = order;
        
       return orderId;
    }

     /**
     * @dev check if the stop-limit order is expired or should be executed if the price reaches the stop/limit value.
     *
     * @param orderId  The order id     
     *
     * @return status code: 
     *                     0: can execute.
     *                     1: expired.
     *                     2: not yet reach limit or stop.
     */
    function checkOrder(bytes32 orderId) external view returns (uint8) {
        require(orders[orderId].orderOwner != address(0), "checkOrder: invalid order id");

        Order memory order = orders[orderId];        
        uint256 currentPrice =  getPairPrice(orders[orderId].tokenA, orders[orderId].tokenB, orders[orderId].amountA);

        if(orders[orderId].expiryDate <= block.timestamp){
            return 1;
        }    
        else{
            if(currentPrice >= order.stopHighPairPrice || currentPrice <= order.stopLowPairPrice){
                return 0;
            }else{
                return 2;
            }
        }
    }

     /**
     * @dev check if the stop-limit order is expired or should be executed if the price reaches the stop/limit value.
     *
     * @param orderId  The order id     
     *
     * @return true: success, false: failure.
     *                     
     */
    function executeOrder(bytes32 orderId) external returns (bool){
        require(orders[orderId].orderOwner != address(0), "executeOrder: invalid order id");       

        uint256 price = getPairPrice(orders[orderId].tokenA, orders[orderId].tokenB, orders[orderId].amountA);        
        if(price >= orders[orderId].stopHighPairPrice || price <= orders[orderId].stopLowPairPrice){
            uint256[] memory amounts = swap(orders[orderId].tokenB, orders[orderId].amountB, orders[orderId].tokenA);
            emit OnTokenSwapped(orderId, orders[orderId].orderOwner, orders[orderId].tokenB, orders[orderId].tokenA, amounts[0], amounts[1]);
    
            uint256 newAmountA = amounts[1];
            uint256 profit     = 0;

            if (newAmountA > orders[orderId].amountA) {
                profit = newAmountA.sub(orders[orderId].amountA);
            }
            
            if(orders[orderId].autoRepay){                 
                 if (profit > 0) {
                     repayBorrow(orders[orderId].orderOwner, orders[orderId].ctokenA, orders[orderId].amountA);
                     IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, profit);
                 }else{
                     repayBorrow(orders[orderId].orderOwner, orders[orderId].ctokenA, newAmountA);
                 }        
             }else{
                 IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, newAmountA);                
             }

             delete orders[orderId];
             emit OnOrderExecuted(orderId, newAmountA);
             return true;
        }else{
            return false;
        }
    }

//for test only
        function executeOrderTest(bytes32 orderId, bool istest, uint256 nTestNewAmountA) external returns (bool){
        require(orders[orderId].orderOwner != address(0), "executeOrder: invalid order id");       

        uint256 price = getPairPrice(orders[orderId].tokenA, orders[orderId].tokenB, orders[orderId].amountA);        
        if(price >= orders[orderId].stopHighPairPrice || price <= orders[orderId].stopLowPairPrice || istest){
            uint256[] memory amounts = swap(orders[orderId].tokenB, orders[orderId].amountB, orders[orderId].tokenA);
            emit OnTokenSwapped(orderId, orders[orderId].orderOwner, orders[orderId].tokenB, orders[orderId].tokenA, amounts[0], amounts[1]);
    
            uint256 newAmountA = amounts[1];
            uint256 profit     = 0;

            if(istest) {
                newAmountA = nTestNewAmountA;
            }
            if (newAmountA > orders[orderId].amountA) {
                profit = newAmountA.sub(orders[orderId].amountA);
            }
            
            if(orders[orderId].autoRepay){
                 if (profit > 0) {
                     repayBorrow(orders[orderId].orderOwner, orders[orderId].ctokenA, orders[orderId].amountA);
                     IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, profit);
                 }else{
                     repayBorrow(orders[orderId].orderOwner, orders[orderId].ctokenA, newAmountA);
                 }               
             }else{
                 IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, newAmountA);                
             }

             delete orders[orderId];
             emit OnOrderExecuted(orderId, newAmountA);
             return true;
        }else{
            return false;
        }
    }

    /**
     * @dev cancel a valid order.
      *
     * @param orderId  The order id     
     *
     * @return true: success, false: failure.
     *
     */
    function cancelOrder(bytes32 orderId) external returns(bool){
        require(orders[orderId].orderOwner != address(0), "cancelOrder: invalid order id");
        require(hasRole(EXECUTOR_ROLE, msg.sender) || msg.sender == orders[orderId].orderOwner, "cancelOrder: no permission to cancel order");

        IERC20 erc20TokenB = IERC20(orders[orderId].tokenB);
        erc20TokenB.transfer(orders[orderId].orderOwner, orders[orderId].amountB);
        delete orders[orderId];
        emit OnOrderCanceled(orderId, orders[orderId].amountB);

        return true;
    }

    /**
     * @dev get a valid order.
      *
     * @param orderId  The order id     
     *
     * @return orderOwner  The address of order owner
     *         ctokenA     The address of ctoken A
     *         tokenA      The address of token A
     *         tokenB      The address of token B
     *         amountA     The token A amount
     *         stopHighPairPrice  limit token pair price
     *         stopLowPairPrice   stop token pair price
     *         expiryDate   expiry date
     *         autoRepay    if automatically repay borrow after trading
     *
     */
    function getOrder(bytes32 orderId) external view returns(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay){
        require(orders[orderId].orderOwner != address(0), "cancelOrder: invalid order id");
        Order memory order = orders[orderId];        
        orderOwner = order.orderOwner;
        ctokenA    = order.ctokenA;
        tokenA     = order.tokenA;
        tokenB     = order.tokenB;
        amountA    = order.amountA;
        amountB    = order.amountB;    
        stopHighPairPrice = order.stopHighPairPrice;
        stopLowPairPrice  = order.stopLowPairPrice;     
        expiryDate = order.expiryDate;
        autoRepay  = order.autoRepay;              
    }

    /**
     * @dev Repay user's borrow.
     *
     * @param borrower     The address of order owner
     * @param borrowToken  The address of ctoken A
     * @param borrowAmount The address of token A     
     *
     * @return uint256 0=success, otherwise a failure.
     *
     */
    function repayBorrow(address borrower, address borrowToken, uint256 borrowAmount) internal onlyRole(EXECUTOR_ROLE) returns (uint256) {
        require(borrowAmount > 0, "repayBorrow: amount is zero");
        uint256 result = CErc20Interface(borrowToken).repayBorrowBehalf(borrower, borrowAmount);
        return result;
    }

     /**
     * @dev exchange tokens via DEX UNISWAP.
     *
     * @param tokenA  The address of token A
     * @param amountA The token A amount
     * @param tokenB  The address of token B 
     *
     * @return uint256[], exact number after swapping in DEX UNISWAP.
     *
     */
    function swap(address tokenA,uint256 amountA, address tokenB) internal returns (uint256[] memory) {
        require(tokenA != address(0), "swap: invalid token A");
        require(tokenB != address(0), "swap: invalid token B");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        // approve Uniswap to swap tokens
        IERC20(tokenA).approve(address(router), amountA);

        uint256 amountOutMin = 0;
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountA, amountOutMin, path, address(this), deadline);

        return amounts;
    }
 
     /**
     * @dev Get token pair price via DEX UNISWAP.
     *
     * @param tokenA  The address of token A     
     * @param tokenB  The address of token B 
     * @param amountA The token A amount
     *
     * @return  uint256 0=success, otherwise a failure.
     *
     */
    function getPairPrice(address tokenA, address tokenB, uint amountA) public view returns(uint256) {
        IUniswapV2Router02 UniswapV2Router = router;
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(UniswapV2Router.factory());
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "getPairPrice: pair not found");
        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint256 Res0, uint256 Res1,) = UniswapV2Pair.getReserves();
        uint256 amountOut = router.getAmountOut(amountA, Res0, Res1);
        uint256 price = amountOut * 10**18 / amountA;
        return price;
   }
}