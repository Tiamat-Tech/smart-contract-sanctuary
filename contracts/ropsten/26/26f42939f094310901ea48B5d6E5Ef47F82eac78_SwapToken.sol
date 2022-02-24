// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SwapToken is Ownable {
  uint256 private _rate;
  uint256 private _rateDecimal;

  constructor(uint256 _exchangeRate, uint256 _exchangeRateDecimal) {
    _rate = _exchangeRate;
    _rateDecimal = _exchangeRateDecimal;
  }

  function changeRate(uint256 _exchangeRate) external onlyOwner {
    require(_rate > 0, "The rate between token and crypto must be greater than 0");
    _rate = _exchangeRate;
  }

  function deposit(address _tokenAddress, uint256 _tokenIn, uint8 _tokenDecimals) external {
    require(_tokenAddress != address(0), "Can't deposit 0 token address");
    require(_tokenIn > 0, "The amount of token in must be greater than 0");
    ERC20 token = ERC20(_tokenAddress);

    uint256 tokenReceive = _tokenIn * (10 ** (uint256)(token.decimals() - _tokenDecimals));
    require(token.transferFrom(msg.sender, address(this), tokenReceive));
  }

  function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint8 _amountDecimals) external {
    require(_tokenIn != address(0) && _tokenOut != address(0), "Cannot swap token at 0 address");
    require(_amountIn > 0, "Token amount must be greater than 0");

    ERC20 tokenIn = ERC20(_tokenIn);
    ERC20 tokenOut = ERC20(_tokenOut);

    uint256 amountIn = _amountIn * (10 ** uint256(tokenIn.decimals() - _amountDecimals));
    uint256 amountOut = _amountIn * (10 ** uint256(tokenIn.decimals() - _amountDecimals)) * _rate;
    require(tokenIn.transferFrom(msg.sender, address(this), amountIn));
    require(tokenOut.transfer(msg.sender, amountOut));
  }

  function getRate() public view returns (uint256) {
    return _rate;
  }
}