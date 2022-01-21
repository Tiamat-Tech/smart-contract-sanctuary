// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import './interfaces/IUniswapV2Factory.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IUniswapV2Router02.sol';
import './libraries/UniswapV2Library.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

// Ownable Contract
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() public{
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function geUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    //Locks the contract for owner for the amount of time provided
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }

    //Unlocks the contract for owner when _lockTime is exceeds
    function unlock() public virtual {
        require(
            _previousOwner == msg.sender,
            "You don't have permission to unlock"
        );
        require(block.timestamp > _lockTime, "Contract is locked until 7 days");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}
interface AnjiReferral {
    function referralBuy(address referrer, uint256 bnbBuy, address tokenAddr) external;
}

contract AnjiRouterUniswap is IUniswapV2Router02 , Ownable{
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;
    //address public USDT;
    address public anji;
    address public anjiReferral;
    uint256 private USDTThreshold;

    address public feeReceiver;
    bool public feeOFF = false;
    bool public transactionFeeReferral = true;
    bool public callReferralBuy = false;
    uint balanceBefore;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'AnjiRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH, address _anji) public {
        factory = _factory;
        WETH = _WETH;
        //USDT = _USDT;
        feeReceiver = msg.sender;
        anji = _anji;
    }    

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // function setFactoryAddress(address _factory) public onlyOwner {
    //     factory = _factory;
    // }

    // function setWETHAddress(address _WETH) public onlyOwner {
    //     WETH = _WETH;
    // }

    function setAnjiAddress(address _anji) public onlyOwner {
        anji = _anji;
    }

    function setReceiverAddress(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function setUSDTThreshold(uint256 _threshold) public onlyOwner {
        USDTThreshold = _threshold;
    }

    function setFeeOFF(bool _feeOFF) public onlyOwner {
        feeOFF = _feeOFF;
    }

    function setTransactionFeeReferral(bool _feeReferral) public onlyOwner {
        transactionFeeReferral = _feeReferral;
    }

    function setReferralBuy(bool _ReferralBuy) public onlyOwner {
        callReferralBuy = _ReferralBuy;
    }

    function setAnjiReferral(address _anjiReferral) public onlyOwner {
        anjiReferral = _anjiReferral;
    }

    function _feeAmount(uint amount, address tokenIn, bool isReferrer, uint usd) public view returns (uint) {
        if (tokenIn == anji && feeOFF == true) {
            return 0;
        }
        if (transactionFeeReferral == true){
            if (isReferrer == true){
                return amount.mul(2)/1000;
            }
        }

        //uint feeAmount;
        // uint256 balance = IERC20(anji).balanceOf(msg.sender);
        if (usd> USDTThreshold) {
            return amount.mul(1)/1000;
            //feeAmount = 1;
        } else {
            return amount.mul(2)/1000;
            //feeAmount = 2;
        }

        // if (balance > 1000000000) {
        //     address[] memory path = new address[](3);
        //     path[0] = anji;
        //     path[1] = WETH;
        //     path[2] = USDT;
        //     uint256[] memory amountsOut = UniswapV2Library.getAmountsOut(factory, balance, path);
        //     if (amountsOut[2] > USDTThreshold) {
        //         feeAmount = 1;
        //     } else {
        //         feeAmount = 2;
        //     }
        // } else {
        //     feeAmount = 2;
        // }

        //uint fee = amount.mul(feeAmount)/1000;
        //return fee;

    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, uint256 usd)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        uint fee = _feeAmount(amountIn, path[1], false, usd);
        uint amount = amountIn - fee;
        amounts = UniswapV2Library.getAmountsOut(factory, amount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);

        if (fee > 0) {
            TransferHelper.safeTransferETH(feeReceiver, fee);
        }
               
    }

    function referrerSwapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, address referrer, uint deadline, uint256 usd)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(msg.sender != referrer, "Sender=Referrer");
        require(referrer != address(0), "No Referrer");
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        uint fee = _feeAmount(amountIn, path[1] ,true, usd);
        uint amount = amountIn - fee;
        amounts = UniswapV2Library.getAmountsOut(factory, amount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        //send the fee to the fee receiver
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeReceiver, fee/2);
            TransferHelper.safeTransferETH(referrer, fee/2);
        }

        if(callReferralBuy == true){
            AnjiReferral(anjiReferral).referralBuy(referrer, msg.value, path[1]);
        }
        
    }


    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline, uint256 usd)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'AnjiRouter: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));

        uint fee = _feeAmount(amounts[amounts.length - 1], path[0],false, usd);
        uint sendingAmount = amounts[amounts.length - 1].sub(fee);
        
        if (fee > 0){
            IWETH(WETH).withdraw(fee);
            TransferHelper.safeTransferETH(feeReceiver, fee);
        }

        IWETH(WETH).withdraw(sendingAmount);
        TransferHelper.safeTransferETH(to, sendingAmount);
        
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline, uint256 usd)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'AnjiRouter: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));

        uint fee = _feeAmount(amounts[amounts.length - 1], path[0], false, usd);
        uint sendingAmount = amounts[amounts.length - 1].sub(fee);

        if (fee > 0){
            IWETH(WETH).withdraw(fee);
            TransferHelper.safeTransferETH(feeReceiver, fee);
        }

        IWETH(WETH).withdraw(sendingAmount);
        TransferHelper.safeTransferETH(to, sendingAmount);
        
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline, uint256 usd)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);

        uint fee = _feeAmount(amounts[0], path[1], false, usd);
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeReceiver, fee);
        }
        // refund dust eth, if any
        if (msg.value - fee > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0] - fee);
        
    }

    function referrerSwapETHForExactTokens(uint amountOut, address[] calldata path, address to, address referrer, uint deadline, uint256 usd)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(msg.sender != referrer, "Sender=Referrer");
        require(referrer != address(0), "No Referrer");
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'AnjiRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);

        //send the fee to the fee receiver
        uint fee = _feeAmount(amounts[0], path[1], true, usd);
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeReceiver, fee/2);
            TransferHelper.safeTransferETH(referrer, fee/2);
        }
        // refund dust eth, if any
        if (msg.value - fee > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0] - fee);

        if(callReferralBuy == true){
            AnjiReferral(anjiReferral).referralBuy(referrer, msg.value, path[1]);
        }
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint256 usd
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        uint fee = _feeAmount(amountIn, path[1], false, usd);
        uint amount = amountIn - fee;
        IWETH(WETH).deposit{value: amount}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amount));
        balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
         if (fee > 0) {
            TransferHelper.safeTransferETH(feeReceiver, fee);
        }
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        
    }

    function referralSwapExactETHForTokensSupportingFeeOnTransferTokens(uint amountOutMin, address[] calldata path, address to, address referrer, uint deadline, uint256 usd)
        external
        virtual
        payable
        ensure(deadline)
    {
        require(msg.sender != referrer, "Sender=Referrer");
        require(referrer != address(0), "NoReferrer");
        require(path[0] == WETH, 'AnjiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        uint fee = _feeAmount(amountIn, path[1], true, usd);
        uint amount = amountIn - fee;
        IWETH(WETH).deposit{value: amount}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amount));
        balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        if (fee > 0) {
            TransferHelper.safeTransferETH(feeReceiver, fee/2);
            TransferHelper.safeTransferETH(referrer, fee/2);
        }        
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        if(callReferralBuy == true){
            AnjiReferral(anjiReferral).referralBuy(referrer, msg.value, path[1]);
        }
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline, 
        uint256 usd
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'AnjiRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'AnjiRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        uint fee = _feeAmount(amountOut, path[0],false, usd);
        uint sendingAmount = amountOut.sub(fee);

        if (fee > 0){
            IWETH(WETH).withdraw(fee);
            TransferHelper.safeTransferETH(feeReceiver, fee);
        }

        IWETH(WETH).withdraw(sendingAmount);
        TransferHelper.safeTransferETH(to, sendingAmount);
 
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}