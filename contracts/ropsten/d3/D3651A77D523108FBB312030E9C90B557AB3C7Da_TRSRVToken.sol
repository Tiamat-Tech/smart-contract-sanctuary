//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract TRSRVToken is ERC20, ERC20Wrapper {
  constructor(address underlyingToken)
    ERC20("tRSRV", "tRSRV")
    // solhint-disable-next-line no-empty-blocks
    ERC20Wrapper(IERC20(underlyingToken)) {
  }
}