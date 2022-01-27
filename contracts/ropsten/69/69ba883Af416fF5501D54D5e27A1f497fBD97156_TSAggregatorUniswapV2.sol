// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { ReentrancyGuard } from "../lib/ReentrancyGuard.sol";
import { SafeTransferLib } from "../lib/SafeTransferLib.sol";
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

contract TSAggregatorUniswapV2 is ReentrancyGuard {
    using SafeTransferLib for address;

    uint256 public fee;
    address public feeRecipient;
    address public weth;
    IUniswapRouterV2 public swapRouter;

    constructor(
        uint256 _fee,
        address _feeRecipient,
        address _weth,
        address _swapRouter
    ) {
        fee = _fee;
        feeRecipient = _feeRecipient;
        weth = _weth;
        swapRouter = IUniswapRouterV2(_swapRouter);
    }

    // Needed for the swap router to be able to send back ETH
    receive() external payable {}

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

    function skimFee(uint256 amount) internal returns (uint256) {
        if (fee != 0 && feeRecipient != address(0)) {
            uint256 feeAmount = (amount * fee) / 10000;
            (bool sent,) = feeRecipient.call{value: feeAmount}("");
            require(sent, "failed to send");
            amount -= feeAmount;
        }
        return amount;
    }
}