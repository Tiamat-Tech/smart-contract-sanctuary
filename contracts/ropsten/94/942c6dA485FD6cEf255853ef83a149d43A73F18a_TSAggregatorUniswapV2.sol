// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { SafeTransferLib } from "../lib/SafeTransferLib.sol";
import { TSAggregator } from "./TSAggregator.sol";
import { IThorchainRouter } from "./interfaces/IThorchainRouter.sol";

interface IUniswapRouterV2 {
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to, uint deadline
    ) external payable;
}

contract TSAggregatorUniswapV2 is TSAggregator {
    using SafeTransferLib for address;

    address public weth;
    IUniswapRouterV2 public swapRouter;

    constructor(address _weth, address _swapRouter) {
        weth = _weth;
        swapRouter = IUniswapRouterV2(_swapRouter);
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

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = weth;
        swapRouter.swapExactTokensForETH(
            amount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint amountOut = skimFee(address(this).balance);
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
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = token;
        swapRouter.swapExactETHForTokens{value: amount}(
            amountOutMin,
            path,
            to,
            type(uint).max // deadline
        );
    }
}