// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

library SwapWithLP {

    using SafeMath for uint256;

    event UpdateRouter(address indexed newAddress, address indexed oldAddress);
//    event UpdatePair(address indexed newAddress, address indexed oldAddress);

//    event SwapETHForTokens(uint256 amount, address[] path);
    event SwapTokens(uint256 amount, address[] path);

//    IUniswapV2Router02 public uniswapV2Router;
//    address public uniswapV2Pair;

    function swapTokensForEth(IUniswapV2Router02 uniswapV2Router, address destination, uint256 tokenAmount) public {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            destination,
            block.timestamp
        );
        emit SwapTokens(tokenAmount, path);
    }

    function swapETHForTokens(IUniswapV2Router02 uniswapV2Router, address tokenAddress, uint256 amount, address destination) public {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        if(amount > address(this).balance){
            amount = address(this).balance;
        }

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            destination, // Burn address
            block.timestamp.add(300)
        );

        emit SwapTokens(amount, path);
    }

    function addLiquidity(IUniswapV2Router02 uniswapV2Router, address destination, uint256 tokenAmount, uint256 ethAmount) public {
        // approve token transfer to cover all possible scenarios

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            destination,
            block.timestamp
        );
    }

}