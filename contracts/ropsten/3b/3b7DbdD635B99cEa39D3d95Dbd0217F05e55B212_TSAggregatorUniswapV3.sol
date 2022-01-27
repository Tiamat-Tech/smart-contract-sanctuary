// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import { ReentrancyGuard } from "../lib/ReentrancyGuard.sol";
import { SafeTransferLib } from "../lib/SafeTransferLib.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
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

contract TSAggregatorUniswapV3 is ReentrancyGuard {
    using SafeTransferLib for address;

    uint256 public fee;
    address public feeRecipient;
    IWETH9 public weth;
    uint24 public poolFee;
    IUniswapRouterV3 public swapRouter;

    constructor(
        uint256 _fee,
        address _feeRecipient,
        uint24 _poolFee,
        address _weth,
        address _swapRouter
    ) {
        fee = _fee;
        feeRecipient = _feeRecipient;
        weth = IWETH9(_weth);
        poolFee = _poolFee;
        swapRouter = IUniswapRouterV3(_swapRouter);
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