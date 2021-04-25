// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/SafeMath.sol";
import "./interfaces/IVeeProxyController.sol";
import "./interfaces/IERC20.sol";
import "./VeeSystemController.sol";
import "./interfaces/compound/CEtherInterface.sol";
import "./interfaces/uniswap/IWETH.sol";
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
contract VeeProxyController is IVeeProxyController, VeeSystemController, Initializable{    
    using SafeMath for uint256;

   address private _priceOracleAddress;
   address private _cether;
   IUniswapV2Router02 private _router;


    /**
     * @dev increasing number for generating random.
     */
    uint256 private nonce;

    /**
     * @dev Comptroller is the risk management layer of the Compound protocol.
     */
    // ComptrollerInterface public comptroller;

    


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
     * @dev Orders
     */
    mapping (bytes32 => Order) public orders;

    receive() payable external{}
    /**
     * @dev Sets the values for {comptroller} and {router}.
     */
    // function initialize(address comptroller_, address router_, address cether,address veeFactoryAddress, address veeSwapAddress, address veeOracleAddress) public initializer {
    //     _setRoleAdmin(PROXY_ADMIN_ROLE, PROXY_ADMIN_ROLE);
    //     _setRoleAdmin(EXECUTOR_ROLE,    PROXY_ADMIN_ROLE);

    //     // deployer + self administration
    //     _setupRole(PROXY_ADMIN_ROLE, _msgSender());
    //     _setupRole(PROXY_ADMIN_ROLE, address(this));

    //     // executor
    //     _setupRole(EXECUTOR_ROLE, _msgSender());   

    //     comptroller = ComptrollerInterface(comptroller_);   

    //     veeProxyFactory = VeeProxyFactory(veeFactoryAddress);
    //     veeSwap = AbsVeeSwap(veeSwapAddress);
    //     veeOracle = IVeePriceOracle(veeOracleAddress);
    //     _cether = cether;

    //     _notEntered = true;
    // }

    constructor (address router_, address cether){
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
     * @param maxSlippage    if automatically repay borrow after trading
     *
     * @return orderId 
     */
    function createOrderERC20ToERC20(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external veeLock(uint8(VeeLockState.LOCK_CREATE)) override returns (bytes32 orderId){
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
       uint256[] memory amounts = swapERC20ToERC20(tokenA, amountA, tokenB, maxSlippage);
       orderId = keccak256(abi.encode(orderOwner, amountA, tokenA, tokenB, getRandom()));
    
       emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
       emit OnOrderCreated(orderId, orderOwner, tokenA, tokenB, amountA, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);

        {
            Order memory order = Order(orderOwner, ctokenA, tokenA, tokenB, amountA, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);
            orders[orderId] = order;
        }
       
    }

    function createOrderERC20ToETH(address orderOwner, address ctokenA, address tokenA, uint256 amountA, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external veeLock(uint8(VeeLockState.LOCK_CREATE)) override returns (bytes32 orderId){
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
       address tokenB = _router.WETH();
       uint256[] memory amounts = swapERC20ToETH(tokenA, amountA, maxSlippage);
       orderId = keccak256(abi.encode(orderOwner, amountA, tokenA, tokenB, getRandom()));
    
       emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
       emit OnOrderCreated(orderId, orderOwner, tokenA, tokenB, amountA, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);

        {
            Order memory order = Order(orderOwner, ctokenA, tokenA, tokenB, amountA, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);
            orders[orderId] = order;
        }
       
    }


    function createOrderETHToERC20(address orderOwner, address cETH,  address tokenB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage) external override veeLock(uint8(VeeLockState.LOCK_CREATE)) payable returns (bytes32 orderId){
        require(orderOwner != address(0), "createOrder: invalid order owner");
        require(cETH != address(0), "createOrder: invalid ctoken A");
        require(stopHighPairPrice != 0, "createOrder: invalid limit price");
        require(stopLowPairPrice != 0, "createOrder: invalid stop limit");
        require(msg.value != 0, "createOrder: eth amount can't be zero.");
        require(expiryDate > block.timestamp, "createOrder: expiry date must be in future.");

        payable(address(this)).transfer(msg.value);
       // swap tokens
       address tokenA = _router.WETH();
       assert(tokenA != address(0));

       uint256[] memory amounts =  swapETHToERC20(tokenB, maxSlippage);
       orderId = keccak256(abi.encode(orderOwner, msg.value, tokenA, tokenB, getRandom()));
    
       emit OnTokenSwapped(orderId, orderOwner, tokenA, tokenB, amounts[0], amounts[1]);
       emit OnOrderCreated(orderId, orderOwner, tokenA, tokenB, msg.value, stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);

       Order memory order = Order(orderOwner, cETH, tokenA, tokenB, msg.value, amounts[1], stopHighPairPrice, stopLowPairPrice, expiryDate, autoRepay, maxSlippage);
       orders[orderId] = order;
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
    function checkOrder(bytes32 orderId) external view override returns (uint8) {
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "checkOrder: invalid order id");
             
        uint256 currentPrice =  getPairPrice(order.tokenA, order.tokenB, order.amountA);

        if(order.expiryDate <= block.timestamp){
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
    function executeOrder(bytes32 orderId) external onlyExecutor nonReentrant veeLock(uint8(VeeLockState.LOCK_EXECUTEDORDER)) override returns (bool){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "executeOrder: invalid order id");       

        uint256 price = getPairPrice(order.tokenA, order.tokenB, order.amountA);    

        if(price >= order.stopHighPairPrice || price <= order.stopLowPairPrice){
            uint256[] memory amounts;
            if(order.tokenB == _router.WETH()){
                amounts = swapETHToERC20(order.tokenB, order.maxSlippage);
            }else{
                if(order.tokenA == _router.WETH()){
                    amounts = swapERC20ToETH(order.tokenB, order.amountB, order.maxSlippage);
                }else{
                    amounts = swapERC20ToERC20(order.tokenA, order.amountA, order.tokenB, order.maxSlippage);
                }
            }
            emit OnTokenSwapped(orderId, order.orderOwner, order.tokenB, order.tokenA, amounts[0], amounts[1]);
            require(amounts[1] != 0, "executeOrder: failed to swap tokens"); 

            uint256 newAmountA = amounts[1];
            uint256 charges    = 0;

            address weth = _router.WETH();
            if(order.autoRepay){
                uint256 borrowedTotal = CTokenInterface(order.ctokenA).borrowBalanceStored(order.orderOwner);
                uint256 repayAmount = order.amountA;

                //In method repayBorrow() the repay borrowing amount must be less and equal than total borrowing of the user in tokenA.
                //if not, an exception will occur.
                //If borrowing amount of the stop-limit order is less and equal than total borrowing amount, then repay the borrowing amount of the order.
                //if borrowing amount of the stop-limit order is above than total borrowing amount, then repay total borrowing amount of the user in tokenA.
                if (borrowedTotal < order.amountA) {
                    repayAmount = borrowedTotal;
                }
                if (newAmountA > repayAmount) {
                    charges = newAmountA.sub(repayAmount);
                }
                if (charges > 0) {
                    if (repayAmount > 0) {
                        repayBorrow(order.ctokenA, order.orderOwner, repayAmount);
                    }
                    if(weth == order.tokenA){
                        // IWETH(weth).withdraw(charges);
                        payable(order.orderOwner).transfer(charges);
                    }else{
                        assert(IERC20(order.tokenA).transfer(order.orderOwner, charges));
                    }
                    
                 }else{
                     repayBorrow(order.ctokenA, order.orderOwner, newAmountA);
                 }             
             }else{
                if(weth == order.tokenA){
                    // IWETH(weth).withdraw(newAmountA);
                    payable(order.orderOwner).transfer(newAmountA);
                }else{
                    assert(IERC20(order.tokenA).transfer(order.orderOwner, newAmountA));
                }               
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
         Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "executeOrder: invalid order id");       

        uint256 price = getPairPrice(order.tokenA, order.tokenB, order.amountA);       

        if(price >= order.stopHighPairPrice || price <= order.stopLowPairPrice || istest){
            uint256[] memory amounts = swapERC20ToERC20(order.tokenB, order.amountB, order.tokenA,order.maxSlippage);
            emit OnTokenSwapped(orderId, order.orderOwner, order.tokenB, order.tokenA, amounts[0], amounts[1]);
            require(amounts[1] != 0, "executeOrder: failed to swap tokens"); 

            uint256 newAmountA = amounts[1];
            uint256 charges    = 0;

            if(istest) {
                newAmountA = nTestNewAmountA;
            }
            address weth = _router.WETH();
            if(order.autoRepay){
                uint256 borrowedTotal = CTokenInterface(order.ctokenA).borrowBalanceStored(order.orderOwner);
                uint256 repayAmount = order.amountA;

                //In method repayBorrow() the repay borrowing amount must be less and equal than total borrowing of the user in tokenA.
                //if not, an exception will occur.
                //If borrowing amount of the stop-limit order is less and equal than total borrowing amount, then repay the borrowing amount of the order.
                //if borrowing amount of the stop-limit order is above than total borrowing amount, then repay total borrowing amount of the user in tokenA.                
                if (borrowedTotal < order.amountA) {
                    repayAmount = borrowedTotal;
                }
                if (newAmountA > repayAmount) {
                    charges = newAmountA.sub(repayAmount);
                }
                if (charges > 0) {
                    if (repayAmount > 0) {
                        repayBorrow(order.ctokenA, order.orderOwner, repayAmount);
                    }
                    if(weth == order.tokenA){
                        // IWETH(weth).withdraw(charges);
                        payable(order.orderOwner).transfer(charges);
                    }else{
                        assert(IERC20(order.tokenA).transfer(order.orderOwner, charges));
                    }
                    
                 }else{
                     repayBorrow(order.ctokenA, order.orderOwner, newAmountA);
                 }             
             }else{
                if(weth == order.tokenA){
                    // IWETH(weth).withdraw(newAmountA);
                    payable(order.orderOwner).transfer(newAmountA);
                }else{
                    assert(IERC20(order.tokenA).transfer(order.orderOwner, newAmountA));
                }               
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
    function cancelOrder(bytes32 orderId) external nonReentrant veeLock(uint8(VeeLockState.LOCK_CANCELORDER)) override returns(bool){
        Order memory order = orders[orderId];
        require(order.orderOwner != address(0), "cancelOrder: invalid order id");
        require(hasRole(EXECUTOR_ROLE, msg.sender) || msg.sender == order.orderOwner, "cancelOrder: no permission to cancel order");
        address weth = _router.WETH();
        if(order.tokenB == weth){
            // IWETH(weth).withdraw(order.amountB);
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
    function getOrderDetail(bytes32 orderId) external view override returns(address orderOwner, address ctokenA, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 stopHighPairPrice, uint256 stopLowPairPrice, uint256 expiryDate, bool autoRepay,uint256 maxSlippage){
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
     * @dev Repay user's borrow.
     *
     * @param cToken      The address of ctoken A
     * @param borrower    The address of order owner
     * @param repayAmount The amount  of token A     
     *
     * @return ret 0: success, otherwise a failure.
     *
     */   
    function repayBorrow(address cToken, address borrower, uint repayAmount) internal returns(uint256 ret) {
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
        
            ret = cErc20Inst.repayBorrowBehalf(borrower, repayAmount);
            require(ret == 0, "repayBorrow: failed to call repayBorrowBehalf");  
        }
             
    }   

    /**
     * @dev set executor role by administrator.
     *
     * @param newExecutor  The address of new executor   
     *
     */
    function setExecutor(address newExecutor) external override onlyAdmin {
        require(newExecutor != address(0), "setExecutor: address of Executor is invalid");
        grantRole(EXECUTOR_ROLE, newExecutor);     
   }

    /**
     * @dev remove an executor role from list by administrator.
     *
     * @param executor  The address of an executor   
     *
     */
    function removeExecutor(address executor) external override onlyAdmin {
        require(executor != address(0), "removeExecutor: address of executor is invalid");
        revokeRole(EXECUTOR_ROLE, executor);      
   }
   

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
    

    function swapERC20ToERC20(address tokenA,uint256 amountA, address tokenB,uint256 maxSlippage) public  returns (uint256[] memory){
        require(tokenA != address(0), "swap: invalid token A");
        require(tokenB != address(0), "swap: invalid token B");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        // approve Uniswap to swap tokens    
        uint256 allowance = IERC20(tokenA).allowance(address(this), address(_router));
        if(allowance < amountA){
            require(IERC20(tokenA).approve(address(_router), amountA), "swap: failed to approve");
        }   
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts;
        uint256 amountOutMin = getMinAmountOut(tokenA,tokenB,amountA,maxSlippage);
        amounts = _router.swapExactTokensForTokens(amountA, amountOutMin, path, address(this), deadline);
        return amounts;
    }

    function swapETHToERC20(address tokenB,uint256 maxSlippage) public payable returns (uint256[] memory){
        require(tokenB != address(0), "swap: invalid token B");

        address[] memory path = new address[](2);
        path[0] = _router.WETH();
        path[1] = tokenB;
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts;
        uint256 amountOutMin = getMinAmountOut(_router.WETH(),tokenB,msg.value,maxSlippage);
        amounts = _router.swapExactETHForTokens{value:msg.value}(amountOutMin, path, address(this), deadline);
        return amounts;
    }

    function swapERC20ToETH(address tokenA,uint256 amountA, uint256 maxSlippage) public  returns (uint256[] memory){
        require(tokenA != address(0), "swap: invalid token A");

        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = _router.WETH();

        // approve Uniswap to swap tokens    
        uint256 allowance = IERC20(tokenA).allowance(address(this), address(_router));
        if(allowance < amountA){
            require(IERC20(tokenA).approve(address(_router), amountA), "swap: failed to approve");
        }   
    
        uint256 deadline = (block.timestamp + 99999999);
        uint256[] memory amounts;
        uint256 amountOutMin = getMinAmountOut(tokenA,_router.WETH(),amountA,maxSlippage);
        amounts = _router.swapExactTokensForETH(amountA, amountOutMin, path, address(this), deadline);
        
        return amounts;
    }

    function getMinAmountOut(address tokenA, address tokenB, uint amountA, uint256 maxSlippage)  internal view returns (uint256 minAmountOut) {
        require(amountA != 0, "getMinAmountOut: amountA can't be zero");

        // IUniswapV2Router02 UniswapV2Router = router;
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(_router.factory());
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "getMinAmountOut: token pair not found");

        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint256 Res0, uint256 Res1,) = UniswapV2Pair.getReserves();        
        uint256 amountOut= _router.getAmountOut(amountA, Res0, Res1) ;  
        minAmountOut = amountOut - ((amountOut * maxSlippage) / 10**18/ 100);      
    }


    function getPairPrice(address tokenA, address tokenB, uint amountA) internal view returns(uint256 price){
        require(amountA != 0, "getPairPrice: amountA can't be zero");

        IUniswapV2Router02 UniswapV2Router = _router;
        IUniswapV2Factory UniswapV2Factory = IUniswapV2Factory(UniswapV2Router.factory());
        address factoryAddress = UniswapV2Factory.getPair(tokenA, tokenB);
        require(factoryAddress != address(0), "getPairPrice: token pair not found");

        IUniswapV2Pair UniswapV2Pair = IUniswapV2Pair(factoryAddress);
        (uint256 Res0, uint256 Res1,) = UniswapV2Pair.getReserves();        
        price = _router.getAmountOut(amountA, Res0, Res1) * 10**18 / amountA;  
        require(price != 0, "executeOrder: failed to get PairPrice"); 
    }

}