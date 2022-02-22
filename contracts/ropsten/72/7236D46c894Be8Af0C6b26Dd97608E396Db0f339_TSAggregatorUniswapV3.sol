// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { SafeTransferLib } from "../lib/SafeTransferLib.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { TSAggregator } from "./TSAggregator.sol";
import { IThorchainRouter } from "./interfaces/IThorchainRouter.sol";

interface IUniswapRouterV3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract TSAggregatorUniswapV3 is TSAggregator {
    using SafeTransferLib for address;

    IWETH9 public weth;
    uint24 public poolFee;
    IUniswapRouterV3 public swapRouter;

    constructor(uint24 _poolFee, address _weth, address _swapRouter) {
        weth = IWETH9(_weth);
        poolFee = _poolFee;
        swapRouter = IUniswapRouterV3(_swapRouter);
    }

    function swapIn(
        address tcRouter,
        address tcVault,
        string calldata tcMemo,
        address token,
        uint amount,
        uint amountOutMin,
        uint deadline
    ) public nonReentrant {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeApprove(address(swapRouter), amount);

        uint amountOut = swapRouter.exactInputSingle(IUniswapRouterV3.ExactInputSingleParams({
            tokenIn: token,
            tokenOut: address(weth),
            fee: poolFee,
            recipient: address(this),
            deadline: deadline,
            amountIn: amount,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        }));
        weth.withdraw(amountOut);

        amountOut = skimFee(amountOut);
        IThorchainRouter(tcRouter).depositWithExpiry{value: amountOut}(
            payable(tcVault),
            address(0), // ETH
            amountOut,
            tcMemo,
            deadline
        );
    }

    function swapOut(address token, address to, uint256 amountOutMin) public payable nonReentrant {
        uint256 amount = skimFee(msg.value);
        weth.deposit{value: amount}();
        swapRouter.exactInputSingle(IUniswapRouterV3.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: token,
            fee: poolFee,
            recipient: to,
            deadline: type(uint).max,
            amountIn: amount,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        }));
    }
}