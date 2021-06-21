// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.8.0;

// TODO: connect with @liquifi
import './liquifi-core/interfaces/PoolFactory.sol';
import './liquifi-core/interfaces/DelayedExchangePool.sol';
import {WETH as IWETH} from './liquifi-core/interfaces/WETH.sol';
import {ERC20 as IERC20} from './liquifi-core/interfaces/ERC20.sol';

import './libraries/SafeMath.sol';
import './libraries/TransferHelper.sol';
import './libraries/LiquifiLibrary.sol';
import { ConvertETH } from './interfaces/ILiquifiRouter01.sol';
import './interfaces/ILiquifiRouter02.sol';


contract LiquifiRouter is ILiquifiRouter02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'LiquifiRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) {
        factory =_factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    /* ---- ADD LIQUIDITY ---- */
    function _addLiquidity(
        address tokenA,      address tokenB,
        uint amountADesired, uint amountBDesired,
        uint amountAMin,     uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pool if it doesn't exist yet
        // if (LiquifiLibrary.poolFor(factory, tokenA, tokenB) == address(0)) {
        //     (address token0, address token1) = LiquifiLibrary.sortTokens(tokenA, tokenB);
        //     PoolFactory(factory).getPool(token0, token1);
        // }

        (address token0,) = LiquifiLibrary.sortTokens(tokenA, tokenB);
        address pool = LiquifiLibrary.poolFor(factory, tokenA, tokenB);
        DelayedExchangePool(pool).processDelayedOrders();

        (uint reserve0, uint reserve1) = LiquifiLibrary.getReserves(pool);
        (uint reserveA, uint reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = LiquifiLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'LiquifiRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = LiquifiLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'LiquifiRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _emitMint(address tokenA, uint amountA, address tokenB, uint amountB, uint liquidity, address to, ConvertETH convertETH) internal virtual {
        (address token0, address token1) = LiquifiLibrary.sortTokens(tokenA, tokenB);
        (uint amount0, uint amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);
        emit Mint(token0, amount0, token1, amount1, liquidity, to, convertETH);
    }

    function addLiquidity(
        address tokenA,      address tokenB,
        uint amountADesired, uint amountBDesired,
        uint amountAMin,     uint amountBMin,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(
            tokenA,         tokenB,
            amountADesired, amountBDesired,
            amountAMin,     amountBMin
        );

        address pool = LiquifiLibrary.poolFor(factory, tokenA, tokenB);
        TransferHelper.smartTransferFrom(tokenA, msg.sender, pool, amountA);
        TransferHelper.smartTransferFrom(tokenB, msg.sender, pool, amountB);
        liquidity = DelayedExchangePool(pool).mint(to);
        _emitMint(tokenA, amountA, tokenB, amountB, liquidity, to, ConvertETH.NONE);
    }

    function addLiquidityETH(
        address token, uint amountTokenDesired, uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline)
    returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,              WETH,
            amountTokenDesired, msg.value,
            amountTokenMin,     amountETHMin
        );

        address pool = LiquifiLibrary.poolFor(factory, token, WETH);

        TransferHelper.smartTransferFrom(token, msg.sender, pool, amountToken);

        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pool, amountETH));

        liquidity = DelayedExchangePool(pool).mint(to);
        _emitMint(WETH, amountETH, token, amountToken, liquidity, to, ConvertETH.IN_ETH);

        if (msg.value > amountETH) {
            TransferHelper.smartTransferETH(msg.sender, msg.value - amountETH);
        }
    }


    /* ---- REMOVE LIQUIDITY ---- */
    function _removeLiquidity(
        address tokenA,  address tokenB,  uint liquidity,
        uint amountAMin, uint amountBMin,
        address to, ConvertETH convertETH
    ) internal virtual returns (uint amountA, uint amountB) {
        address pool = LiquifiLibrary.poolFor(factory, tokenA, tokenB);
        require(
            DelayedExchangePool(pool).transferFrom(msg.sender, pool, liquidity), // send liquidity to pool
            "LiquifiRouter: TRANSFER_FROM_FAILED"
        );
        
        (uint amount0, uint amount1) = DelayedExchangePool(pool).burn(to, false);
        (address token0, address token1) = LiquifiLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'LiquifiRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'LiquifiRouter: INSUFFICIENT_B_AMOUNT');
    }

    function _emitBurn(address tokenA, uint amountA, address tokenB, uint amountB, uint liquidity, address to, ConvertETH convertETH) internal virtual {
        (address token0, address token1) = LiquifiLibrary.sortTokens(tokenA, tokenB);
        (uint amount0, uint amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);
        emit Burn(token0, amount0, token1, amount1, liquidity, to, convertETH);
    }

    function removeLiquidity(
        address tokenA,  address tokenB,  uint liquidity,
        uint amountAMin, uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        (amountA, amountB) = _removeLiquidity(
            tokenA,     tokenB,     liquidity,
            amountAMin, amountBMin,
            to, ConvertETH.NONE
        );
        _emitBurn(tokenA, amountA, tokenB, amountB, liquidity, to, ConvertETH.NONE);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = _removeLiquidity(
            token,          WETH,           liquidity,
            amountTokenMin, amountETHMin,
            address(this),  ConvertETH.OUT_ETH
        );
        TransferHelper.smartTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.smartTransferETH(to, amountETH);
        _emitBurn(token, amountToken, WETH, amountETH, liquidity, to, ConvertETH.OUT_ETH);
    }

    // not supported
    function removeLiquidityWithPermit(
        address tokenA,     address tokenB, uint liquidity,
        uint amountAMin,    uint amountBMin,
        address to, uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) public  virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        require(false, "LiquifiRouter: UNSUPPORTED_METHOD");
        (amountA, amountB) = (0, 0);
    }
    
    // not supported
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) public  virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        require(false, "LiquifiRouter: USING_UNSUPPORTED_METHOD");
        (amountToken, amountETH) = (0, 0);
    }

    /* ---- REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ---- */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = _removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            ConvertETH.OUT_ETH
        );
        uint amountToken = IERC20(token).balanceOf(address(this));
        TransferHelper.smartTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.smartTransferETH(to, amountETH);
        _emitBurn(token, amountToken, WETH, amountETH, liquidity, to, ConvertETH.OUT_ETH);
    }

    // not supported
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        require(false, "LiquifiRouter: UNSUPPORTED_METHOD");
        amountETH = 0;
    }


    /* ---- SWAP ---- */
    // requires the initial amount to have already been sent to the first pool
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = LiquifiLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? LiquifiLibrary.poolFor(factory, output, path[i + 2]) : _to;
            
            // TODO: false not forever. Fix it
            DelayedExchangePool(LiquifiLibrary.poolFor(factory, input, output)).swap(
                to, false, amount0Out, amount1Out, new bytes(0)
            );
            _emitSwap(input, amount0Out, output, amount1Out, to, ConvertETH.NONE);
        }
    }

    function _emitSwap(address tokenIn, uint amountIn, address tokenOut, uint amountOut, address to, ConvertETH convertETH) internal virtual {
        uint fee = LiquifiLibrary.getInstantSwapFee(LiquifiLibrary.poolFor(factory, tokenIn, tokenOut));
        emit Swap(tokenIn, amountIn, tokenOut, amountOut, to, convertETH, fee);
    }

    function _processDelayedOrders(address factory, address[] memory path) internal virtual {
        require(path.length >= 2, 'LiquifiRouter: INVALID_PATH');
        for (uint i = 0; i < path.length - 1; i++) {
            address pool = LiquifiLibrary.poolFor(factory, path[i], path[i + 1]);
            DelayedExchangePool(pool).processDelayedOrders();
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        _processDelayedOrders(factory, path);

        amounts = LiquifiLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'LiquifiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.smartTransferFrom(path[0], msg.sender, LiquifiLibrary.poolFor(factory, path[0], path[1]), amounts[0]);

        // bool isTokenAIn = properOrder(tokenIn, tokenOut);
        // (uint amountAOut, uint amountBOut, uint fee) = getAmountsOut(pool, isTokenAIn, amountIn, minAmountOut);
        // DelayedExchangePool(pool).swap(to, convertETH == ConvertETH.OUT_ETH, amountAOut, amountBOut, new bytes(0));
        // amountOut = isTokenAIn ? amountBOut : amountAOut;
        // emit Swap(tokenIn, amountIn, tokenOut, amountOut, to, convertETH, fee);

        // DelayedExchangePool(LiquifiLibrary.poolFor(factory, input, output)).swap(
        //     to, false, amount0Out, amount1Out, new bytes(0)
        // );

        // _emitSwap(path[0], amountIn, path[1], amounts[0], to, ConvertETH.NONE);
        // _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // address pool = LiquifiLibrary.poolFor(factory, input, output);
        // DelayedExchangePool(pool).processDelayedOrders();

        amounts = LiquifiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'LiquifiRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.smartTransferFrom(
            path[0], msg.sender, LiquifiLibrary.poolFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, 'LiquifiRouter: INVALID_PATH');

        // address pool = LiquifiLibrary.poolFor(factory, input, output);
        // DelayedExchangePool(pool).processDelayedOrders();

        amounts = LiquifiLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'LiquifiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(LiquifiLibrary.poolFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, 'LiquifiRouter: INVALID_PATH');

        // address pool = LiquifiLibrary.poolFor(factory, input, output);
        // DelayedExchangePool(pool).processDelayedOrders();

        amounts = LiquifiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'LiquifiRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.smartTransferFrom(
            path[0], msg.sender, LiquifiLibrary.poolFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.smartTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, 'LiquifiRouter: INVALID_PATH');

        // address pool = LiquifiLibrary.poolFor(factory, input, output);
        // DelayedExchangePool(pool).processDelayedOrders();

        amounts = LiquifiLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'LiquifiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.smartTransferFrom(
            path[0], msg.sender, LiquifiLibrary.poolFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.smartTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, 'LiquifiRouter: INVALID_PATH');

        // address pool = LiquifiLibrary.poolFor(factory, input, output);
        // DelayedExchangePool(pool).processDelayedOrders();

        amounts = LiquifiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'LiquifiRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(LiquifiLibrary.poolFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.smartTransferETH(msg.sender, msg.value - amounts[0]);
    }

    /* ---- SWAP (supporting fee-on-transfer tokens) ---- */
    // requires the initial amount to have already been sent to the first pair
    // TODO: check it
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = LiquifiLibrary.sortTokens(input, output);
            address pool = LiquifiLibrary.poolFor(factory, input, output);
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
                // process long swaps
                DelayedExchangePool(pool).processDelayedOrders();

                (uint reserve0, uint reserve1) = LiquifiLibrary.getReserves(factory, input, output);
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = ERC20(input).balanceOf(pool).sub(reserveInput);
                uint fee = LiquifiLibrary.getInstantSwapFee(pool);
                amountOutput = LiquifiLibrary.getAmountOut(amountInput, reserveInput, reserveOutput, 1000 - fee);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? LiquifiLibrary.poolFor(factory, output, path[i + 2]) : _to;
            // TODO: again false?
            DelayedExchangePool(pool).swap(to, false, amount0Out, amount1Out, new bytes(0));
            emit Swap(input, amount0Out, output, amount1Out, to, ConvertETH.NONE, LiquifiLibrary.getInstantSwapFee(pool)); // TODO: check it
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.smartTransferFrom(
            path[0], msg.sender, LiquifiLibrary.poolFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = ERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            ERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'LiquifiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) {
        require(path[0] == WETH, 'LiquifiRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(LiquifiLibrary.poolFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = ERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            ERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'LiquifiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, 'LiquififRouter: INVALID_PATH');
        TransferHelper.smartTransferFrom(
            path[0], msg.sender, LiquifiLibrary.poolFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = ERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'LiquififRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.smartTransferETH(to, amountOut);
    }



    /* ---- LIBRARY FUNCTIONS ---- */
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override
    returns (uint amountB) {
        return LiquifiLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure virtual override
    returns (uint amountOut) {
        return LiquifiLibrary.getAmountOut(amountIn, reserveIn, reserveOut, 997); // TODO: for some pool have same fee, update it
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure virtual override
    returns (uint amountIn) {
        return LiquifiLibrary.getAmountIn(amountOut, reserveIn, reserveOut, 997); // TODO: for some pool have same fee, update it
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view virtual override
    returns (uint[] memory amounts) {
        return LiquifiLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path) public view virtual override 
    returns (uint[] memory amounts) {
        return LiquifiLibrary.getAmountsIn(factory, amountOut, path);
    }
}