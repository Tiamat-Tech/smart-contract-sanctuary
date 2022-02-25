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

  event rateChange(uint256 _newRate);
  event Deposit(address _from, uint256 _amount, uint8 _decimals);
  event Swap(address _in, address _out, uint256 _tokenIn, uint256 _tokenOut);

  function changeRate(uint256 _exchangeRate) external onlyOwner {
    require(_rate > 0, "The rate between token and crypto must be greater than 0");
    _rate = _exchangeRate;
    emit rateChange(_exchangeRate);
  }

  function deposit(address _tokenAddress, uint256 _tokenIn, uint8 _tokenDecimals) external payable {
    require(_tokenAddress != address(0), "Can't deposit 0 token address");
    require(_tokenIn > 0, "The amount of token in must be greater than 0");
    ERC20 token = ERC20(_tokenAddress);

    uint256 tokenReceive = _tokenIn * (10 ** (uint256)(token.decimals() - _tokenDecimals));
    require(token.transferFrom(msg.sender, address(this), tokenReceive));
    emit Deposit(msg.sender, _tokenIn, _tokenDecimals);
  }

  function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint8 _amountDecimals) external payable {
    if(_tokenIn != address(0) && _tokenOut != address(0)) { // swap token for token
      _tokenSwap(_tokenIn, _tokenOut, _amountIn, _amountDecimals);
    } else if(_tokenIn == address(0)) { // swap native token for token
      ERC20 token = ERC20(_tokenOut);
      uint256 nativeAmount = msg.value;
      uint256 amountOut = nativeAmount * _rate / (10 ** _rateDecimal);
      require(token.transfer(msg.sender, amountOut));
      emit Swap(_tokenIn, _tokenOut, nativeAmount, amountOut);
    } else if(_tokenOut == address(0)) { // swap token for native token
      ERC20 token = ERC20(_tokenIn);
      uint256 nativeOut = _amountIn * (10 ** _rateDecimal) / _rate;
      uint256 amountIn = _amountIn * (10 ** uint256(token.decimals()- _amountDecimals));
      require(token.transferFrom(msg.sender, address(this), amountIn));
      payable(msg.sender).transfer(nativeOut);
      emit Swap(_tokenIn, _tokenOut, amountIn, nativeOut);
    }
  }

  function getRate() public view returns (uint256) {
    return _rate;
  }

  function _tokenSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint8 _amountDecimals) private {
    ERC20 tokenIn = ERC20(_tokenIn);
    ERC20 tokenOut = ERC20(_tokenOut);

    uint256 amountIn = _amountIn * (10 ** uint256(tokenIn.decimals() - _amountDecimals));
    uint256 amountOut = _amountIn * (10 ** uint256(tokenIn.decimals() - _amountDecimals)) * _rate;
    require(tokenIn.transferFrom(msg.sender, address(this), amountIn));
    require(tokenOut.transfer(msg.sender, amountOut));
    emit Swap(_tokenIn, _tokenOut, amountIn, amountOut);
  }
}