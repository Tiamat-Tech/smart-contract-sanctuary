//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import "../ISupportedDex.sol";
import "./ISushiswapV2Router.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//it implements the ISupportedDex, and call ISushiswapV2Router to invoke the sushiswap smart contract on mainnet

contract SushiswapV2Dex is ISupportedDex {

    address public sushiswapV2;

    constructor(address _sushiswapV2) {
        sushiswapV2 = _sushiswapV2;
    }

    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) override public view returns (uint256 out, uint256 liquidityFee) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        uint256[] memory amountsOut = ISushiswapV2Router(sushiswapV2).getAmountsOut(amountIn, path);
        require(amountsOut.length == 2, "Unexpected number of outputs for getAmountsOut");
        return (amountsOut[1], 0);
    }

  function swapExactIn(
    address recipient,
    uint256 amountIn,
    uint256 minAmountOut,
    address tokenIn,
    address tokenOut,
    uint256 expireTime
  ) override public returns (uint256 amountOut, uint256 liquidityFee) {
      require(IERC20(tokenIn).balanceOf(msg.sender) >= amountIn, "Insufficient funds");
      require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn, "Not enough allowance");
      require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Could not pull funds");
      require(IERC20(tokenIn).approve(sushiswapV2, amountIn));
      address[] memory path = new address[](2);
      path[0] = tokenIn;
      path[1] = tokenOut;
      uint256[] memory amounts = ISushiswapV2Router(sushiswapV2).swapExactTokensForTokens(amountIn, minAmountOut, path, recipient, expireTime);
      return (amounts[1], 0);
  }

}