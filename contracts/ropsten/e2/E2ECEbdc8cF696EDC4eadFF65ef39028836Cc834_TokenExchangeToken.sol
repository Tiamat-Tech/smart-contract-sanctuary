// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ExchangeToken.sol";

contract TokenExchangeToken {
  ERC20 public tokenA;
  ERC20 public tokenB;

  uint256 public tokenABalance;
  uint256 public tokenBBalance;
  uint private rate;
  uint private rateDecimal;

  constructor(ERC20 _tokenA, ERC20 _tokenB, uint _rate, uint8 _rateDecimal) public {
    tokenA = _tokenA;
    tokenB = _tokenB;
    rate = _rate;
    rateDecimal = _rateDecimal;
  }

  event Deposit(address user, uint256 tokenAAmount, uint256 tokenBAmount, uint tokenADecimal, uint tokenBDecimal);
  event SwapTokens(address user, address fromToken, address toToken);

  function deposit(uint256 _tokenAAmount, uint256 _tokenBAmount, uint8 _tokenADecimal, uint8 _tokenBDecimal) public {
    uint256 tokenAAmountUnit = _tokenAAmount * (10 ** (uint256)(18 - _tokenADecimal));
    uint256 tokenBAmountUnit = _tokenBAmount * (10 ** (uint256)(18 - _tokenBDecimal));

    require(tokenA.transferFrom(msg.sender, address(this), tokenAAmountUnit));
    require(tokenB.transferFrom(msg.sender, address(this), tokenBAmountUnit));

    tokenABalance += tokenAAmountUnit;
    tokenBBalance += tokenBAmountUnit;

    emit Deposit(msg.sender, _tokenAAmount, _tokenBAmount, _tokenADecimal, _tokenBDecimal);
  }

  function swapTokenAToTokenB(uint _tokenAmount, uint8 _tokenDecimals) public {
    uint256 tokenAAmountUnit = _tokenAmount * (10 ** (uint256)(18 - _tokenDecimals));
    require(tokenA.transferFrom(msg.sender, address(this), tokenAAmountUnit));

    uint256 tokenBAmountUnit = (_tokenAmount * (10 ** (uint256)(18 - _tokenDecimals - rateDecimal))) * rate;
    require(tokenB.transfer(msg.sender, tokenBAmountUnit));

    emit SwapTokens(msg.sender, address(tokenA), address(tokenB));
  }

  function swapTokenBToTokenA(uint _tokenAmount, uint8 _tokenDecimals) public {
    uint256 tokenBAmountUnit = _tokenAmount * (10 ** (uint256)(18 - _tokenDecimals));
    require(tokenB.transferFrom(msg.sender, address(this), tokenBAmountUnit));

    uint256 tokenAAmountUnit = (_tokenAmount * (10 ** (uint256)(18 - _tokenDecimals + rateDecimal))) / rate;
    require(tokenA.transfer(msg.sender, tokenAAmountUnit));

    emit SwapTokens(msg.sender, address(tokenB), address(tokenA));
  }
}