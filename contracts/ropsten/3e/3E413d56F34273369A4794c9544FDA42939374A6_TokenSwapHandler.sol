//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import "./ISupportedDex.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


contract TokenSwapHandler {

  // @notice emitted when a swap occurs through this contract
  event Swap(
    address indexed dexAddress,
    address indexed recipient,
    uint256 amountIn,
    uint256 amountOut,
    address indexed tokenIn,
    address tokenOut,
    uint256 liquidityFee
  );

  event Here(string here);

  function getQuotes(
    address dexAddress,
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) public view returns (uint256 out, uint256 liquidityFee) {
    return ISupportedDex(dexAddress).getQuote(tokenIn, tokenOut, amountIn);
  }

  function swapExactIn(
    address recipient,
    address dexAddress,
    uint256 amountIn,
    uint256 minAmountOut,
    address tokenIn,
    address tokenOut,
    uint256 expireTime
  ) public returns (uint256 out, uint256 fee) {
    emit Here("here");
    require(expireTime > block.timestamp, "Swap request has expired!");

    require(IERC20(tokenIn).balanceOf(msg.sender) >= amountIn, "Insufficient funds");
    require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn, "Not enough allowance");
    require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Could not pull funds");
    require(IERC20(tokenIn).approve(dexAddress, amountIn));
    uint256 preSwapRecipientBalance = IERC20(tokenOut).balanceOf(recipient);
    (uint256 amountOut, uint256 liquidityFee) = ISupportedDex(dexAddress).swapExactIn(
      recipient,
      amountIn,
      minAmountOut,
      tokenIn,
      tokenOut,
      expireTime
    );
    uint256 postSwapRecipientBalance = IERC20(tokenOut).balanceOf(recipient);

    require(amountOut >= minAmountOut, "Amount received must be at least minAmountOut");
    require(preSwapRecipientBalance + amountOut == postSwapRecipientBalance, "Received amount mismatch");

    emit Swap(dexAddress, recipient, amountIn, amountOut, tokenIn, tokenOut, liquidityFee);
    return (amountOut, liquidityFee);
  }
}