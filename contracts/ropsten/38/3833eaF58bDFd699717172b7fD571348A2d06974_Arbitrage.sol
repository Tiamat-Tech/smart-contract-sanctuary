// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "FlashLoanReceiverBase.sol";
import "ILendingPoolAddressesProvider.sol";
import "ILendingPool.sol";

import "ISwapRouter.sol";
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
    uint256 private executionType = 0;

    IUniswapRouter private constant uniswapRouter =
        IUniswapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV2Router02 private constant sushiRouter =
        IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    // _addressProvider is the lending pool address
    constructor(address _addressProvider)
        FlashLoanReceiverBase(_addressProvider)
        public
    {}

    function _tradeOnUniswapV3(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) public {
        uint24 fee = 10000;
        address recipient = address(this);

        uint160 sqrtPriceLimitX96 = 0;
        uint256 deadline = block.timestamp + 300;

        IERC20(tokenOut).approve(address(uniswapRouter), type(uint256).max);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams(
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
    }

    function _tradeOnSushi(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) public {
        address recipient = address(this);
        uint256 deadline = block.timestamp + 300;

        IERC20(tokenOut).approve(address(sushiRouter), type(uint256).max);

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
    ) external override {
        require(
            _amount <= getBalanceInternal(address(this), _reserve),
            "Invalid balance, was the flashLoan successful?"
        );

        // trading logic goes here.
        // !! Ensure that *this contract* has enough of `_reserve` funds to payback the `_fee` !!

        if (executionType >= 2) {
            for (uint256 i = 0; i < tradePaths.length; i++) {
                TradePath memory tradePath = tradePaths[i];
                if (
                    keccak256(abi.encodePacked(tradePath.exchange)) ==
                    keccak256(abi.encodePacked("uniswapv3"))
                ) {
                    // _tradeOnUniswapV3(
                    //     tradePath.tokenIn,
                    //     tradePath.tokenOut,
                    //     tradePath.amountIn,
                    //     tradePath.amountOutMinimum
                    // );
                } else if (
                    keccak256(abi.encodePacked(tradePath.exchange)) ==
                    keccak256(abi.encodePacked("sushiswap"))
                ) {
                    // _tradeOnSushi(
                    //     tradePath.tokenIn,
                    //     tradePath.tokenOut,
                    //     tradePath.amountIn,
                    //     tradePath.amountOutMinimum
                    // );
                }
            }
        }

        // end trading logic

        uint256 totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    /* Flash loan 1000000000000000000 wei (1 ether) worth of `_asset` */
    function flashloan(address _asset, uint256 _borrowingAmt) public onlyOwner {
        bytes memory data = "";

        ILendingPool lendingPool = ILendingPool(
            addressesProvider.getLendingPool()
        );
        lendingPool.flashLoan(address(this), _asset, _borrowingAmt, data);
    }

    /*
      _asset: the address of the asset we would like to get a flash loan for
      _borrowingAmt: the amount we would like to borrow in wei units
      _tradePaths: the arbitrage trading paths we would like to execute
    */
    function flashArbitrage(
        address _asset,
        uint256 _borrowingAmt,
        uint256 _executionType,
        TradePath[] memory _tradePaths
    ) public onlyOwner {
        executionType = _executionType;

        if (executionType >= 0) {
            for (uint256 i = 0; i < _tradePaths.length; i++) {
                tradePaths.push(_tradePaths[i]);
            }
        }

        if (executionType >= 1) {
            flashloan(_asset, _borrowingAmt);
        }
    }
}