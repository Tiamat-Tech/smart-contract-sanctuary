//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.5;

import "./WrappedERC20.sol";

contract WrappedHogeTestnet is WrappedERC20(ERC20(0xd2f0541B27953D39561a5037F9A22a9e6E677a23)) {}