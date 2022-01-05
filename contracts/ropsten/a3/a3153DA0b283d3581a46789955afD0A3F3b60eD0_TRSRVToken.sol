//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract TRSRVToken is ERC20, ERC20Wrapper {
  uint8 public _decimals;

  constructor(address underlyingToken, uint8 decimalsAmount)
    ERC20("tRSRV", "tRSRV")
    ERC20Wrapper(IERC20(underlyingToken)) {
      _decimals = decimalsAmount;
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }
}