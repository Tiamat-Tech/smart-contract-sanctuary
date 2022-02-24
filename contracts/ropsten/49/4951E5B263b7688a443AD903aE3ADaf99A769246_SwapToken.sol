// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SwapToken {
  event Deposit(address user, uint256 tokenAmount, uint tokenDecimal);
  event SwapTokens(address user, address tokenIn, address tokenOut);

  function deposit(address _token, uint _tokenAmount, uint8 _tokenDecimals) public {
    uint256 tokenAmountUnit = _tokenAmount * (10 ** (uint256)(18 - _tokenDecimals));
    ERC20 token = ERC20(_token);

    require(token.transferFrom(msg.sender, address(this), tokenAmountUnit));

    emit Deposit(msg.sender, _tokenAmount, _tokenDecimals);
  }

  function swapToken(
    address _tokenIn,
    address _tokenOut,
    uint _tokenAmount,
    uint8 _tokenDecimals,
    uint _rate,
    uint8 _rateDecimal
  ) public {
    ERC20 tokenIn = ERC20(_tokenIn);
    ERC20 tokenOut = ERC20(_tokenOut);

    uint256 tokenInAmountUnit = _tokenAmount * (10 ** (uint256)(18 - _tokenDecimals));
    require(tokenIn.transferFrom(msg.sender, address(this), tokenInAmountUnit));

    uint256 tokenOutAmountUnit = (_tokenAmount * (10 ** (uint256)(18 - _tokenDecimals - _rateDecimal))) * _rate;
    require(tokenOut.transfer(msg.sender, tokenOutAmountUnit));

    emit SwapTokens(msg.sender, address(tokenIn), address(tokenOut));
  }

  function getTokenAmout(address token) external view returns (uint) {
    return ERC20(token).balanceOf(address(this));
  }
}