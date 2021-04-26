// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import './WrappedToken.sol';

contract WrappedDPH is WrappedToken {
    constructor() public WrappedToken("Wrapped DPH Token", "DPH") {}
}