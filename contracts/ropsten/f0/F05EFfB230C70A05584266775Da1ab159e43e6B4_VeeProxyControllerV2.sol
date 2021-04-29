// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/SafeMath.sol";
import "./interfaces/IVeeProxyController.sol";
import "./interfaces/IERC20.sol";
import "./VeeSystemController.sol";
import "./interfaces/compound/CEtherInterface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/compound/CTokenInterfaces.sol";
import "./interfaces/uniswap/IUniswapV2Factory.sol";
import "./interfaces/uniswap/IUniswapV2Pair.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
/**
 * @title  Vee's proxy Contract
 * @notice Implementation of the {VeeProxyController} interface.
 * @author Vee.Finance
 */
contract VeeProxyControllerV2 is IVeeProxyController, VeeSystemController, Initializable{    
    using SafeMath for uint256;

   address private _cether;
   IUniswapV2Router02 private _router;

    /**
     * @dev increasing number for generating random.
     */
    uint256 private nonce;

    /**
     * @dev state code for Check Order
     */
    enum StateCode {
            EXECUTE,
            EXPIRED,
            NOT_RUN
        }

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
        uint256 maxSlippage;
    }

    /**
     * @dev container for saving orderid dand order infornmation
     */
    mapping (bytes32 => Order) private orders;

    /**
     * @dev called for plain Ether transfers
     */
    receive() payable external{}
   
    /**
     * @dev initialize for initializing UNISWAP router and CETH
     */
    function initialize(address router_, address cether) public initializer {
        _setRoleAdmin(PROXY_ADMIN_ROLE, PROXY_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE,    PROXY_ADMIN_ROLE);

        // deployer + self administration
        _setupRole(PROXY_ADMIN_ROLE, _msgSender());
        _setupRole(PROXY_ADMIN_ROLE, address(this));

        // executor
        _setupRole(EXECUTOR_ROLE, _msgSender());   

        _cether = cether;
        _router = IUniswapV2Router02(router_);
        _notEntered = true;
    }

    /*** External Functions ***/
     /**
     * @dev Sender create a stop-limit order with the below conditions from ERC20 TO ERC20.
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
     * @param maxSlippage  max acceptable slippage
     *
     * @return orderId 
     */
    function createOrderERC20ToERC20(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external veeLock(uint8(VeeLockState.LOCK_CREATE)) override returns (bytes32 orderId){
        require(orderOwner != address(0), "createOrderERC20ToERC20: invalid order owner");
        require(ctokenA != address(0), "createOrderERC20ToERC20: invalid ctoken A");
        require(tokenA != address(0), "createOrderERC20ToERC20: invalid tokenA");
        require(tokenB != address(0), "createOrderERC20ToERC20: invalid tokenB");        
        require(stopHighPairPrice != 0, "createOrderERC20ToERC20: invalid limit price");
        require(stopLowPairPrice != 0, "createOrderERC20ToERC20: invalid stop price");
        require(amountA != 0, "createOrderERC20ToERC20: amountA can't be zero.");
        require(expiryDate > block.timestamp, "createOrderERC20ToERC20: expiry date must be in the future.");
        
        {
            IERC20 erc20TokenA = IERC20(tokenA);
            uint256 allowance = erc20TokenA.allowance(msg.sender, address(this));
            require(allowance >= amountA,"createOrderERC20ToERC20: allowance must bigger than amountA");
            assert(erc20TokenA.transferFrom(msg.sender, address(this), amountA));
        }        
      
        uint256[] memory amounts = swapERC20ToERC20(tokenA, amountA, tokenB, maxSlippage);
        orderId = keccak256(abi.encode(orderOwner, amountA, tokenA, tokenB, getRandom()));
    
        emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
        emit OnOrderCreated(orderId, orderOwner, tokenA, ctokenA, tokenB, amountA, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);

        {
            Order memory order = Order(orderOwner, ctokenA, tokenA, tokenB, amountA, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);
            orders[orderId] = order;
        }       
    }

    /**
     * @dev Sender create a stop-limit order with the below conditions from ERC20 TO ETH.
     *
     * @param orderOwner  The address of order owner
     * @param ctokenA     The address of ctoken A
     * @param tokenA      The address of token A    
     * @param amountA     The token A amount
     * @param stopHighPairPrice  limit token pair price
     * @param stopLowPairPrice   stop token pair price
     * @param expiryDate   expiry date
     * @param autoRepay    if automatically repay borrow after trading
     * @param maxSlippage  max acceptable slippage
     *
     * @return orderId 
     */
    function createOrderERC20ToETH(address orderOwner, address ctokenA, address tokenA, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external veeLock(uint8(VeeLockState.LOCK_CREATE)) override returns (bytes32 orderId){
        require(orderOwner != address(0), "createOrderERC20ToETH: invalid order owner");
        require(tokenA != address(0), "createOrderERC20ToETH: invalid tokenA");
        require(ctokenA != address(0), "createOrderERC20ToETH: invalid ctoken A");
        require(stopHighPairPrice != 0, "createOrderERC20ToETH: invalid limit price");
        require(stopLowPairPrice != 0, "createOrderERC20ToETH: invalid stop limit");
        require(amountA != 0, "createOrderERC20ToETH: amountA can't be zero.");
        require(expiryDate > block.timestamp, "createOrderERC20ToETH: expiry date must be in future.");
        
        {
            IERC20 erc20TokenA = IERC20(tokenA);
            uint256 allowance = erc20TokenA.allowance(msg.sender, address(this));
            require(allowance >= amountA,"createOrderERC20ToETH: allowance must bigger than amountA");
            assert(erc20TokenA.transferFrom(msg.sender, address(this), amountA));
        }
        
       // swap tokens
       address tokenB = VETH;
       uint256[] memory amounts = swapERC20ToETH(tokenA, amountA, maxSlippage);
       orderId = keccak256(abi.encode(orderOwner, amountA, tokenA, tokenB, getRandom()));
    
       emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
       emit OnOrderCreated(orderId, orderOwner, tokenA, ctokenA, tokenB, amountA, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);

        {
            Order memory order = Order(orderOwner, ctokenA, tokenA, tokenB, amountA, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);
            orders[orderId] = order;
        }       
    }

    /**
     * @dev Sender create a stop-limit order with the below conditions from ETH TO ERC20.
     *
     * @param orderOwner  The address of order owner
     * @param cETH        The address of cETH
     * @param tokenB      The address of token b         
     * @param stopHighPairPrice  limit token pair price
     * @param stopLowPairPrice   stop token pair price
     * @param expiryDate   expiry date
     * @param autoRepay    if automatically repay borrow after trading
     * @param maxSlippage  max acceptable slippage
     *
     * @return orderId 
     */
    function createOrderETHToERC20(address orderOwner, address cETH,  address tokenB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external override veeLock(uint8(VeeLockState.LOCK_CREATE)) payable returns (bytes32 orderId){
        require(orderOwner != address(0), "createOrderETHToERC20: invalid order owner");
        require(tokenB != address(0), "createOrderETHToERC20: invalid tokenB");
        require(cETH != address(0), "createOrderETHToERC20: invalid ctoken A");
        require(stopHighPairPrice != 0, "createOrderETHToERC20: invalid limit price");
        require(stopLowPairPrice != 0, "createOrderETHToERC20: invalid stop limit");
        require(msg.value != 0, "createOrderETHToERC20: eth amount can't be zero.");
        require(expiryDate > block.timestamp, "createOrderETHToERC20: expiry date must be in future.");

       // swap tokens
       address tokenA = VETH;
       uint256[] memory amounts =  swapETHToERC20(tokenB, msg.value, maxSlippage);
       orderId = keccak256(abi.encode(orderOwner, msg.value, tokenA, tokenB, getRandom()));
    
       emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
       emit OnOrderCreated(orderId, orderOwner, tokenA, cETH, tokenB, msg.value, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);

       Order memory order = Order(orderOwner, cETH, tokenA, tokenB, msg.value, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);
       orders[orderId] = order;
    }

     /**
     * @dev check if the stop-limit order is expired or should be executed if the price reaches the stop/limit pair price.
     *
     * @param orderId  The order id     
     *
     * @return status code: 
     *                     StateCode.EXECUTE: execute.
     *                     StateCode.EXPIRED: expired.
     *                     StateCode.NOT_RUN: not yet reach limit or stop.
     */
    function checkOrder(bytes32 orderId) external view override returns (uint8) {
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "checkOrder: invalid order id");
             
        uint256 currentPrice =  getPairPrice(order.tokenB, order.tokenA, order.amountB);        
        if(order.expiryDate <= block.timestamp){
            return (uint8(StateCode.EXPIRED));
        }        
        if(currentPrice >= order.stopHighPairPrice || currentPrice <= order.stopLowPairPrice){
            return (uint8(StateCode.EXECUTE));
        }            
        return (uint8(StateCode.NOT_RUN)); 
    }

    /**
     * @dev execute order if the stop-limit order is expired or should be executed if the price reaches the stop/limit value.
     *
     * @param orderId  The order id     
     *
     * @return true: success, false: failure.
     *                     
     */
    function executeOrder(bytes32 orderId) external onlyExecutor nonReentrant veeLock(uint8(VeeLockState.LOCK_EXECUTEDORDER)) override returns (bool){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0),"executeOrder: invalid order id");
        uint256 price = getPairPrice(order.tokenB, order.tokenA, order.amountB);
        if(price > order.stopLowPairPrice && price < order.stopHighPairPrice){
            return false;
        }
        if(order.tokenA != VETH && order.tokenB != VETH ){
            return excuteOrderERC20ToERC20(order, orderId);
        }else  if(order.tokenA == VETH && order.tokenB != VETH ){
            return executeOrderETHToERC20(order, orderId);
        }
        return executeOrderERC20ToETH(order, orderId);
    }

    /**
     * @dev cancel a valid order.
     *
     * @param orderId  The order id     
     *
     * @return Whether or not the canceling order succeeded
     *
     */
    function cancelOrder(bytes32 orderId) external nonReentrant veeLock(uint8(VeeLockState.LOCK_CANCELORDER)) override returns(bool){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "cancelOrder: invalid order id");
        require(hasRole(EXECUTOR_ROLE, msg.sender) || msg.sender == order.orderOwner, "cancelOrder: no permission to cancel order");
        if(order.tokenB == VETH){            
            payable(order.orderOwner).transfer(order.amountB);
        }else{
            IERC20 erc20TokenB = IERC20(order.tokenB);
            assert(erc20TokenB.transfer(order.orderOwner, order.amountB));
        }
        delete orders[orderId];
        emit OnOrderCanceled(orderId, order.amountB);
        return true;
    }

    /**
     * @dev get details of a valid order .
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
     *         maxSlippage  max acceptable slippage
     *
     */
    function getOrderDetail(bytes32 orderId) external view override returns(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay, uint256 maxSlippage){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "getOrder: invalid order id");   
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
        maxSlippage = order.maxSlippage;         
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
     * @dev remove an executor role from the list by administrator.
     *
     * @param executor  The address of an executor   
     *
     */
    function removeExecutor(address executor) external onlyAdmin {
        require(executor != address(0), "removeExecutor: address of executor is invalid");
        revokeRole(EXECUTOR_ROLE, executor);      
    }   

    /**
     * @dev set new cETH by administrator.
     *
     * @param ceth The address of an cETH   
     *
     */
    function setCETH(address ceth) external onlyAdmin {
        require(ceth != address(0), "setCETH: invalid token");
        _cether = ceth;
    }

    /**
     * @dev set new UNISWAP router by administrator.
     *
     * @param router The address of an router   
     *
     */
    function setRouter(address router) external onlyAdmin {
        require(router != address(0), "setRouter: invalid token");
        _router = IUniswapV2Router02(router);
    }

    /*** Internal Functions ***/
    /**
     * @dev execute order if token A is ERC20 and token B is ERC20.
     *
     * @param order    Details of the order
     * @param orderId  Order id   
     *
     * @return true: success; 
     */
    function excuteOrderERC20ToERC20(Order memory order, bytes32 orderId) internal returns (bool){  
        uint256[] memory amounts = swapERC20ToERC20(order.tokenB, order.amountB, order.tokenA, order.maxSlippage);
        emit OnTokenSwapped(orderId, order.orderOwner, order.tokenB, order.tokenA, amounts[0], amounts[1]);
        require(amounts[1] != 0, "excuteOrderERC20ToERC20: failed to swap tokens"); 

        uint256 newAmountA  = amounts[1];
        uint256 repayAmount = getRealBorrow(order);
        if(!order.autoRepay || repayAmount == 0){
            assert(IERC20(order.tokenA).transfer(order.orderOwner, newAmountA));
            emit OnOrderExecuted(orderId, newAmountA);
            return true;
        }          
        if(newAmountA <= repayAmount){
            repayBorrow(order.ctokenA, order.orderOwner, newAmountA);
        }else {
            repayBorrow(order.ctokenA, order.orderOwner, repayAmount);
            transferERC20Profit(order, newAmountA, repayAmount); 
        }
        delete orders[orderId];
        emit OnOrderExecuted(orderId, newAmountA);
        return true;        
    }

    /**
     * @dev execute order if token A is ETH and token B is ERC20.
     *
     * @param order    Details of the order
     * @param orderId  Order id
     *
     * @return true: success; 
     */
    function executeOrderETHToERC20(Order memory order, bytes32 orderId) internal returns (bool){
        uint256[] memory amounts = swapERC20ToETH(order.tokenB, order.amountB, order.maxSlippage);
        emit OnTokenSwapped(orderId, order.orderOwner, order.tokenB, order.tokenA, amounts[0], amounts[1]);
        require(amounts[1] != 0, "executeOrderETHToERC20: failed to swap tokens"); 

        uint256 newAmountA = amounts[1];
        uint256 repayAmount = getRealBorrow(order);
        if(!order.autoRepay || repayAmount == 0){
            payable(order.orderOwner).transfer(newAmountA);
            emit OnOrderExecuted(orderId, newAmountA);
            return true;
        }      
        if(newAmountA <= repayAmount){
            repayBorrow(order.ctokenA, order.orderOwner, newAmountA);
        }else {
            repayBorrow(order.ctokenA, order.orderOwner, repayAmount);
            transferETHProfit(order, newAmountA, repayAmount); 
        }        
        delete orders[orderId];
        emit OnOrderExecuted(orderId, newAmountA);
        return true;  
    }

    /**
     * @dev execute order if token A is ERC20 and token B is ETH.
     *
     * @param order    Details of the order
     * @param orderId  Order id
     *
     * @return true: success; 
     */
    function executeOrderERC20ToETH(Order memory order, bytes32 orderId) internal returns (bool){
        uint256[] memory amounts = swapETHToERC20(order.tokenA, order.amountB, order.maxSlippage);
        emit OnTokenSwapped(orderId, order.orderOwner, order.tokenB, order.tokenA, amounts[0], amounts[1]);
        require(amounts[1] != 0, "executeOrderERC20ToETH: failed to swap tokens");

        uint256 newAmountA = amounts[1];
        uint256 repayAmount = getRealBorrow(order);
        if(!order.autoRepay || repayAmount == 0){
            assert(IERC20(order.tokenA).transfer(order.orderOwner, newAmountA));
            emit OnOrderExecuted(orderId, newAmountA);
            return true;
        }          
         if(newAmountA <= repayAmount){
            repayBorrow(order.ctokenA, order.orderOwner, newAmountA);
        }else {
            repayBorrow(order.ctokenA, order.orderOwner, repayAmount);
            transferERC20Profit(order, newAmountA, repayAmount); 
        }
        delete orders[orderId];
        emit OnOrderExecuted(orderId, newAmountA);
        return true;          
    }

    /**
     * @dev get real borrow amount of the user on token A.
     *
     * @param order Details of the order   
     *
     * @return repayAmount real borrow amount of the user; 
     */
    function getRealBorrow(Order memory order) internal view returns (uint256 repayAmount){
        uint256 borrowedTotal = CTokenInterface(order.ctokenA).borrowBalanceStored(order.orderOwner);
        repayAmount = order.amountA;       
        if(borrowedTotal < order.amountA){
            repayAmount = borrowedTotal;
        }
    }    
        
    /**
     * @dev Repay user's borrow.
     *
     * @param cToken      The address of ctoken A
     * @param borrower    The address of order owner
     * @param repayAmount The amount  of token A     
     *
     */   
    function repayBorrow(address cToken, address borrower, uint repayAmount) internal {        
        if(cToken == _cether) {
            CEtherInterface cether = CEtherInterface(cToken);
            cether.repayBorrowBehalf{value:repayAmount}(borrower); 
        }else{
            CErc20Interface cErc20Inst = CErc20Interface(cToken);
            CErc20Storage cErc20StorageInst = CErc20Storage(cToken);
            address underlyingAddress = cErc20StorageInst.underlying();
            require(underlyingAddress != address(0), "repayBorrow: invalid underlying Address");

            IERC20 erc20Inst = IERC20(underlyingAddress);
            require(erc20Inst.approve(cToken, repayAmount), "repayBorrow: failed to approve");        
        
            uint ret = cErc20Inst.repayBorrowBehalf(borrower, repayAmount);
            require(ret == 0, "repayBorrow: failed to call repayBorrowBehalf");
        }            
    }   

    /**
     * @dev transfer ERIC 20 profit to the user.
     *
     * @param order       Details of the order
     * @param newAmountA  amount from DEX like UNISWAP
     * @param repayAmount real borrow amount of the user   
     *
     * @return true: success; 
     */
    function transferERC20Profit(Order memory order, uint256 newAmountA, uint256 repayAmount) internal returns (bool){       
        uint256 charges = newAmountA.sub(repayAmount);        
        if(charges > 0){
            assert(IERC20(order.tokenA).transfer(order.orderOwner, charges));           
        }
        return true;
    }

    /**
     * @dev transfer ETH profit to the user.
     *
     * @param order       Details of the order
     * @param newAmountA  amount from DEX like UNISWAP
     * @param repayAmount real borrow amount of the user   
     *
     * @return true: success; 
     */
    function transferETHProfit(Order memory order, uint256 newAmountA, uint256 repayAmount) internal returns (bool){       
        uint256 charges = newAmountA.sub(repayAmount);        
        if(charges > 0){
            payable(order.orderOwner).transfer(charges);           
        }
        return true;
    }

   /**
     * @dev swap ERC20 to ETH token in DEX UNISWAP.
     *
     * @param tokenA      The address of token A 
     * @param amountA     The token A amount        
     * @param maxSlippage max acceptable slippage     
     *
     * @return memory: The input token amount and all subsequent output token amounts.
     *
     */ 
    function swapERC20ToETH(address tokenA, uint256 amountA, uint256 maxSlippage) internal returns (uint256[] memory){
        require(tokenA != address(0), "swapERC20ToETH: invalid token A");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = _router.WETH();
           
        uint256 allowance = IERC20(tokenA).allowance(address(this), address(_router));
        if(allowance < amountA){
            require(IERC20(tokenA).approve(address(_router), amountA), "swapERC20ToETH: failed to approve");
        }   
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts;
        uint256 amountOutMin = getMinAmountOut(tokenA, _router.WETH(), amountA, maxSlippage);
        amounts = _router.swapExactTokensForETH(amountA, amountOutMin, path, payable(address(this)), deadline);        
        return amounts;
    }

    /**
     * @dev swap ETH to ERC20 token in DEX UNISWAP.
     *
     * @param tokenB      The address of token B
     * @param amountA     The eth amount  A
     * @param maxSlippage max acceptable slippage     
     *
     * @return memory: The input token amount and all subsequent output token amounts..
     *
     */ 
    function swapETHToERC20(address tokenB, uint256 amountA, uint256 maxSlippage) internal returns (uint256[] memory){
        require(tokenB != address(0), "swapETHToERC20: invalid token B");

        address[] memory path = new address[](2);
        path[0] = _router.WETH();
        path[1] = tokenB;
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256 amountOutMin = getMinAmountOut(_router.WETH(), tokenB, amountA, maxSlippage);
        uint256[] memory amounts = _router.swapExactETHForTokens{value:amountA}(amountOutMin, path, address(this), deadline);
        return amounts;
    }

    /**
     * @dev swap ERC20 to ERC20 token in DEX UNISWAP.
     *
     * @param tokenA      The address of token A 
     * @param amountA     The token A amount   
     * @param tokenB      The address of token B
     * @param maxSlippage max acceptable slippage     
     *
     * @return memory: The input token amount and all subsequent output token amounts.
     *
     */ 
    function swapERC20ToERC20(address tokenA,uint256 amountA, address tokenB, uint256 maxSlippage) internal returns (uint256[] memory){
        require(tokenA != address(0), "swapERC20ToERC20: invalid token A");
        require(tokenB != address(0), "swapERC20ToERC20: invalid token B");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
           
        uint256 allowance = IERC20(tokenA).allowance(address(this), address(_router));
        if(allowance < amountA){
            require(IERC20(tokenA).approve(address(_router), amountA), "swap: failed to approve");
        }   
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts;
        uint256 amountOutMin = getMinAmountOut(tokenA,tokenB, amountA, maxSlippage);
        amounts = _router.swapExactTokensForTokens(amountA, amountOutMin, path, address(this), deadline);
        return amounts;
    }
    
    
    /**
     * @dev alculates min Amountout by calling getAmountOut() with max acceptable slippage.
     *
     * @param tokenA      The address of token A        
     * @param tokenB      The address of token B
     * @param amountA     The token A amount 
     * @param maxSlippage max acceptable slippage     
     *
     * @return minAmountOut
     *
     */ 
    function getMinAmountOut(address tokenA, address tokenB, uint amountA, uint256 maxSlippage) internal view returns (uint256 minAmountOut) {
        require(amountA != 0, "getMinAmountOut: amountA can't be zero");
        uint256 amountOut = getAmountOut(tokenA, tokenB, amountA); 
        minAmountOut = amountOut - ((amountOut * maxSlippage) / 10**18/ 100);      
    }

     /**
     * @dev alculates token pair price.
     *
     * @param tokenA   The address of token A        
     * @param tokenB   The address of token B
     * @param amountA  The token A amount         
     *
     * @return price
     *
     */ 
    function getPairPrice(address tokenA, address tokenB, uint amountA) internal view returns(uint256 price){
        require(amountA != 0, "getPairPrice: amountA can't be zero"); 
        if(tokenA == VETH){
            tokenA = _router.WETH();
        }    
        if(tokenB == VETH){
            tokenB = _router.WETH();
        }
        price = getAmountOut(tokenA, tokenB, amountA) * 10**18 / amountA;
    }

    /**
     * @dev alculates all subsequent maximum output token amounts by calling getReserves for each pair of token addresses in the path in turn.
     *
     * @param tokenA      The address of token A        
     * @param tokenB      The address of token B   
     *
     * @return amountOut
     *
     */ 
    function getAmountOut(address tokenA, address tokenB,uint256 amountIn) internal view returns(uint256 amountOut){
        IUniswapV2Router02 UniswapV2Router = _router;
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(UniswapV2Router.factory());
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "getAmountOut: token pair not found");

        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint Res0, uint Res1,) = UniswapV2Pair.getReserves();
        if (tokenA < tokenB) {
            amountOut = UniswapV2Router.getAmountOut(amountIn, Res0, Res1);
        } else {
            amountOut = UniswapV2Router.getAmountOut(amountIn, Res1, Res0);
        }
        require(amountOut != 0, "getAmountOut: failed to get PairPrice"); 
    }

    /*** Private Functions ***/
    /**
     * @dev generate random number.     
     *
     */
   function getRandom() private returns (uint256) {
       nonce++;
       uint256 randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) ;
       randomnumber = randomnumber + 1;                
       return randomnumber;
    }   

    function getAddresses() public view returns(address, address){
        return (_cether,address(_router));
    }
    function getNums() public view returns(uint256, address){
        return (nonce, VETH);
    }
}