// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/AccessControl.sol";
import "./utils/SafeMath.sol";
import "./interfaces/IVeeProxyController.sol";
import "./interfaces/compound/CTokenInterfaces.sol";
import "./interfaces/compound/ComptrollerInterface.sol";
import "./interfaces/compound/IPriceOracle.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IERC20.sol";
import './VeeSystemController.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title  Vee's proxy Contract
 * @notice Implementation of the {VeeProxyController} interface.
 * @author Vee.Finance
 */
contract VeeProxyController is IVeeProxyController, VeeSystemController, Initializable{    
    using SafeMath for uint256;
   

    /**
     * @dev Comptroller is the risk management layer of the Compound protocol.
     */
    ComptrollerInterface public comptroller;

    /**
     * @dev Uniswap router for safely swapping tokens.
     */
    IUniswapV2Router02 public router;

    /**
     * @dev Container for order information
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

    enum StateCode {
            EXECUTE,
            EXPIRED,
            NOT_RUN
        }

    /**
     * @dev Mapping of ordere id to order infornmation.
     */
    mapping (bytes32 => Order) public orders;


    /**
     * @dev Sets the values for {comptroller} and {router}.
     */
    function initialize(address comptroller_, address router_) public initializer {
        _setRoleAdmin(PROXY_ADMIN_ROLE, PROXY_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE,    PROXY_ADMIN_ROLE);

        // deployer + self administration
        _setupRole(PROXY_ADMIN_ROLE, _msgSender());
        _setupRole(PROXY_ADMIN_ROLE, address(this));

        // executor
        _setupRole(EXECUTOR_ROLE, _msgSender());   

        comptroller = ComptrollerInterface(comptroller_);
        router = IUniswapV2Router02(router_);      

        _notEntered = true;
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
    function createOrder(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay) external veeLock(uint8(VeeLockState.LOCK_CREATE)) returns (bytes32){
        require(orderOwner != address(0), "createOrder: invalid order owner");
        require(ctokenA != address(0), "createOrder: invalid ctoken A");
        require(stopHighPairPrice != 0, "createOrder: invalid limit price");
        require(stopLowPairPrice != 0, "createOrder: invalid stop limit");
        require(amountA != 0, "createOrder: amountA can't be zero.");
        require(expiryDate > block.timestamp, "createOrder: expiry date must be in future.");
        
        {
            IERC20 erc20TokenA = IERC20(tokenA);
            uint256 allowance = erc20TokenA.allowance(msg.sender, address(this));
            require(allowance >= amountA,"allowance must bigger than amountA");
            assert(erc20TokenA.transferFrom(msg.sender, address(this), amountA));
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
     *                     StateCode.EXECUTE: can execute.
     *                     StateCode.EXPIRED: expired.
     *                     StateCode.NOT_RUN: not yet reach limit or stop.
     */
    function checkOrder(bytes32 orderId) external view veeLock(uint8(VeeLockState.LOCK_CHECKORDER)) returns (uint8) {
        require(orders[orderId].orderOwner != address(0), "checkOrder: invalid order id");
        
        Order memory order = orders[orderId];        
        uint256 currentPrice =  getPairPrice(orders[orderId].tokenA, orders[orderId].tokenB, orders[orderId].amountA);

        if(orders[orderId].expiryDate <= block.timestamp){
            return (uint8(StateCode.EXPIRED));
        }    
        else{
            if(currentPrice >= order.stopHighPairPrice || currentPrice <= order.stopLowPairPrice){
                return (uint8(StateCode.EXECUTE));
            }else{
                return (uint8(StateCode.NOT_RUN));
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
    function executeOrder(bytes32 orderId) external onlyExecutor nonReentrant veeLock(uint8(VeeLockState.LOCK_EXECUTEDORDER)) returns (bool){
        require(orders[orderId].orderOwner != address(0), "executeOrder: invalid order id");       

        uint256 price = getPairPrice(orders[orderId].tokenA, orders[orderId].tokenB, orders[orderId].amountA);    

        if(price >= orders[orderId].stopHighPairPrice || price <= orders[orderId].stopLowPairPrice){
            uint256[] memory amounts = swap(orders[orderId].tokenB, orders[orderId].amountB, orders[orderId].tokenA);
            emit OnTokenSwapped(orderId, orders[orderId].orderOwner, orders[orderId].tokenB, orders[orderId].tokenA, amounts[0], amounts[1]);
            require(amounts[1] != 0, "executeOrder: failed to swap tokens"); 

            uint256 newAmountA = amounts[1];
            uint256 charges    = 0;

            if(orders[orderId].autoRepay){
                uint256 borrowedTotal = CTokenInterface(orders[orderId].ctokenA).borrowBalanceStored(orders[orderId].orderOwner);
                uint256 repayAmount = orders[orderId].amountA;

                //In method repayBorrow() the repay borrowing amount must be less and equal than total borrowing of the user in tokenA.
                //if not, an exception will occur.
                //If borrowing amount of the stop-limit order is less and equal than total borrowing amount, then repay the borrowing amount of the order.
                //if borrowing amount of the stop-limit order is above than total borrowing amount, then repay total borrowing amount of the user in tokenA.
                if (borrowedTotal < orders[orderId].amountA) {
                    repayAmount = borrowedTotal;
                }
                if (newAmountA > repayAmount) {
                    charges = newAmountA.sub(repayAmount);
                }
                if (charges > 0) {
                    if (repayAmount > 0) {
                        repayBorrow(orders[orderId].ctokenA, orders[orderId].orderOwner, repayAmount);
                    }
                    assert(IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, charges));
                 }else{
                     repayBorrow(orders[orderId].ctokenA, orders[orderId].orderOwner, newAmountA);
                 }             
             }else{
                 assert(IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, newAmountA));                
             }

             delete orders[orderId];
             emit OnOrderExecuted(orderId, newAmountA);
             return true;
        }else{
            return false;
        }
    }

//for test only
       function executeOrderTest(bytes32 orderId, bool istest, uint256 nTestNewAmountA) external onlyExecutor nonReentrant veeLock(uint8(VeeLockState.LOCK_EXECUTEDORDER)) returns (bool){
        require(orders[orderId].orderOwner != address(0), "executeOrder: invalid order id");       

        uint256 price = getPairPrice(orders[orderId].tokenA, orders[orderId].tokenB, orders[orderId].amountA);       

        if(price >= orders[orderId].stopHighPairPrice || price <= orders[orderId].stopLowPairPrice || istest){
            uint256[] memory amounts = swap(orders[orderId].tokenB, orders[orderId].amountB, orders[orderId].tokenA);
            emit OnTokenSwapped(orderId, orders[orderId].orderOwner, orders[orderId].tokenB, orders[orderId].tokenA, amounts[0], amounts[1]);
            require(amounts[1] != 0, "executeOrder: failed to swap tokens"); 

            uint256 newAmountA = amounts[1];
            uint256 charges    = 0;

            if(istest) {
                newAmountA = nTestNewAmountA;
            }

            if(orders[orderId].autoRepay){
                uint256 borrowedTotal = CTokenInterface(orders[orderId].ctokenA).borrowBalanceStored(orders[orderId].orderOwner);
                uint256 repayAmount = orders[orderId].amountA;

                //In method repayBorrow() the repay borrowing amount must be less and equal than total borrowing of the user in tokenA.
                //if not, an exception will occur.
                //If borrowing amount of the stop-limit order is less and equal than total borrowing amount, then repay the borrowing amount of the order.
                //if borrowing amount of the stop-limit order is above than total borrowing amount, then repay total borrowing amount of the user in tokenA.                
                if (borrowedTotal < orders[orderId].amountA) {
                    repayAmount = borrowedTotal;
                }
                if (newAmountA > repayAmount) {
                    charges = newAmountA.sub(repayAmount);
                }
                if (charges > 0) {
                    if (repayAmount > 0) {
                        repayBorrow(orders[orderId].ctokenA, orders[orderId].orderOwner, repayAmount);
                    }
                    assert(IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, charges));
                 }else{
                     repayBorrow(orders[orderId].ctokenA, orders[orderId].orderOwner, newAmountA);
                 }             
             }else{
                 assert(IERC20(orders[orderId].tokenA).transfer(orders[orderId].orderOwner, newAmountA));                
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
     * @return Whether or not the canceling order succeeded
     *
     */
    function cancelOrder(bytes32 orderId) external nonReentrant veeLock(uint8(VeeLockState.LOCK_CANCELORDER)) returns(bool){
        require(orders[orderId].orderOwner != address(0), "cancelOrder: invalid order id");
        require(hasRole(EXECUTOR_ROLE, msg.sender) || msg.sender == orders[orderId].orderOwner, "cancelOrder: no permission to cancel order");

        IERC20 erc20TokenB = IERC20(orders[orderId].tokenB);
        assert(erc20TokenB.transfer(orders[orderId].orderOwner, orders[orderId].amountB));
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
    function getOrder(bytes32 orderId) external view veeLock(uint8(VeeLockState.LOCK_GETORDER)) returns(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay){
        require(orders[orderId].orderOwner != address(0), "getOrder: invalid order id");
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
     * @param cToken      The address of ctoken A
     * @param borrower    The address of order owner
     * @param repayAmount The amount  of token A     
     *
     * @return ret 0: success, otherwise a failure.
     *
     */   
    function repayBorrow(address cToken, address borrower, uint repayAmount) internal returns(uint256 ret)
    {
        CErc20Interface cErc20Inst = CErc20Interface(cToken);
        CErc20Storage cErc20StorageInst = CErc20Storage(cToken);
        address underlyingAddress = cErc20StorageInst.underlying();
        require(underlyingAddress != address(0), "repayBorrow: invalid underlying Address");

        IERC20 erc20Inst = IERC20(underlyingAddress);
        require(erc20Inst.approve(cToken, repayAmount), "repayBorrow: failed to approve");        
        
        ret = cErc20Inst.repayBorrowBehalf(borrower, repayAmount);
        require(ret == 0, "repayBorrow: failed to call repayBorrowBehalf");       
    }   

     /**
     * @dev exchange tokens via DEX UNISWAP.
     *
     * @param tokenA  The address of token A
     * @param amountA The token A amount
     * @param tokenB  The address of token B 
     *
     * @return The input token amount and all subsequent output token amounts after trading in DEX UNISWAP.
     *
     */
    function swap(address tokenA,uint256 amountA, address tokenB) internal returns (uint256[] memory) {
        require(tokenA != address(0), "swap: invalid token A");
        require(tokenB != address(0), "swap: invalid token B");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        // approve Uniswap to swap tokens    
        uint256 allowance = IERC20(tokenA).allowance(address(this), address(router));
        if(allowance < amountA){
            require(IERC20(tokenA).approve(address(router), amountA), "swap: failed to approve");
        }   
    
        uint256 amountOutMin;
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
     * @return  price 0=failure, otherwise success.
     *
     */
    function getPairPrice(address tokenA, address tokenB, uint amountA) public view returns(uint256 price) {
        require(amountA != 0, "getPairPrice: amountA can't be zero");

        IUniswapV2Router02 UniswapV2Router = router;
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(UniswapV2Router.factory());
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "getPairPrice: token pair not found");

        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint256 Res0, uint256 Res1,) = UniswapV2Pair.getReserves();        
        price = router.getAmountOut(amountA, Res0, Res1) * 10**18 / amountA;  
        require(price != 0, "executeOrder: failed to get PairPrice");        
   }

    /**
     * @dev set executor role by administrator.
     *
     * @param newExecutor  The address of new executor   
     *
     */
    function setExecutor(address newExecutor) external onlyAdmin {
        require(newExecutor != address(0), "setExecutor: address of Executor is invalid");
        grantRole(EXECUTOR_ROLE, newExecutor);     
   }

    /**
     * @dev remove an executor role from list by administrator.
     *
     * @param executor  The address of an executor   
     *
     */
    function removeExecutor(address executor) external onlyAdmin  {
        require(executor != address(0), "removeExecutor: address of executor is invalid");
        revokeRole(EXECUTOR_ROLE, executor);      
   }
}