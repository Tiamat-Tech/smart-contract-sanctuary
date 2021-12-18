// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import "FlashLoanReceiverBase.sol";
import "ILendingPoolAddressesProvider.sol";
import "ILendingPool.sol";

import "ISwapRouter.sol";
import "IQuoter.sol";
import "IUniswapV2Router02.sol";

import {IERC20, SafeERC20} from "SafeERC20.sol";

interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

struct TradePath {
    string exchange;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

contract Arbitrage is FlashLoanReceiverBase {
    using SafeERC20 for IERC20;

    TradePath[] private tradePaths;
    uint private executionType;

    IUniswapRouter private constant uniswapRouter = IUniswapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV2Router02 private constant sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    // _addressProvider is the lending pool address
    constructor(address _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

    function _tradeOnUniswapV3(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint256 deadline) private {
        uint24 fee = 3000;
        address recipient = msg.sender;
        uint160 sqrtPriceLimitX96 = 0;

        IERC20(tokenIn).safeApprove(address(uniswapRouter), type(uint256).max);
        IERC20(tokenOut).safeApprove(address(uniswapRouter), type(uint256).max);
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            tokenIn,
            tokenOut,
            fee,
            recipient,
            deadline,
            amountIn,
            amountOutMin,
            sqrtPriceLimitX96
        );
        
        uniswapRouter.exactInputSingle(params);
        uniswapRouter.refundETH();
        
        // refund leftover ETH to user
        (bool success,) = msg.sender.call{ value: address(this).balance }("");
        require(success, "refund failed");
    }

    function _tradeOnSushi(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, uint256 deadline) private {
        address recipient = address(this);

        IERC20(tokenIn).safeApprove(address(sushiRouter), type(uint256).max);
        IERC20(tokenOut).safeApprove(address(sushiRouter), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        sushiRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            recipient,
            deadline
        );
    }

    /* This function is called after your contract has received the flash loaned amount */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        // trading logic goes here.
        // !! Ensure that *this contract* has enough of `_reserve` funds to payback the `_fee` !!

        if (executionType >= 2) {
            for (uint i=0; i<tradePaths.length; i++) {
                TradePath memory tradePath = tradePaths[i];
                uint256 deadline = block.timestamp + 300;
                if (keccak256(abi.encodePacked(tradePath.exchange)) == keccak256(abi.encodePacked('uniswapv3'))) {
                _tradeOnUniswapV3(tradePath.tokenIn, tradePath.tokenOut, tradePath.amountIn, tradePath.amountOutMinimum, deadline);
                }
                else if (keccak256(abi.encodePacked(tradePath.exchange)) == keccak256(abi.encodePacked('sushiswap'))) {
                _tradeOnSushi(tradePath.tokenIn, tradePath.tokenOut, tradePath.amountIn, tradePath.amountOutMinimum, deadline);
                }
            }
        }

        // end trading logic

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    /* Flash loan 1000000000000000000 wei (1 ether) worth of `_asset` */
    function flashloan(address _asset, uint _borrowingAmt) private {
        bytes memory data = "";
        uint amount = _borrowingAmt;

        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), _asset, amount, data);
    }

    /*
      _asset: the address of the asset we would like to get a flash loan for
      _borrowingAmt: the amount we would like to borrow in wei units
      _tradePaths: the arbitrage trading paths we would like to execute
    */
    function flashArbitrage(address _asset, uint _borrowingAmt, uint _executionType, TradePath[] memory _tradePaths) public onlyOwner {
        executionType = _executionType;

        if (executionType >= 0)
            for (uint i=0; i<_tradePaths.length; i++) {
                tradePaths.push(_tradePaths[i]);
            }

        if (executionType >= 1)
            flashloan(_asset,_borrowingAmt);
    }
}