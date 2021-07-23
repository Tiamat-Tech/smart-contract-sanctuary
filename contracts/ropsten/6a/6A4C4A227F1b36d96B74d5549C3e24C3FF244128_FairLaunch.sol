// SPDX-License-Identifier: MIT
pragma solidity ^0.5;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswap.sol";

contract FairLaunch {
  address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address private constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

  event Log(string message, uint val);

  function addLiquidity(
    address _token,
    uint _amountA,
    uint _amountETH
  ) external {
    IERC20(_token).approve(ROUTER, _amountA);
    // IERC20(_token).transferFrom(msg.sender, address(this), _amountA);
      IUniswapV2Router(ROUTER).addLiquidityETH.value(_amountETH)(
        _token,
        _amountA,
        _amountA,
        _amountETH,
        address(this),
        block.timestamp
      );
    // emit Log("amountA", amountA);
    // emit Log("amountB", amountB);
    // emit Log("liquidity", liquidity);
  }

  function removeLiquidity(address _tokenA, address _tokenB) external {
    address pair = IUniswapV2Factory(FACTORY).getPair(_tokenA, _tokenB);

    uint liquidity = IERC20(pair).balanceOf(address(this));
    IERC20(pair).approve(ROUTER, liquidity);

    (uint amountA, uint amountB) =
      IUniswapV2Router(ROUTER).removeLiquidity(
        _tokenA,
        _tokenB,
        liquidity,
        1,
        1,
        address(this),
        block.timestamp
      );

    emit Log("amountA", amountA);
    emit Log("amountB", amountB);
  }

  function receive () public payable   {
    emit Log("received", 1);
  }

  function () external payable {
    emit Log("received", 1);
  }

}