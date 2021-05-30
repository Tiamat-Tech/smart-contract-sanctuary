// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import './WrappedToken.sol';

contract WrappedEXOS is WrappedToken {
    constructor() public WrappedToken("Wrapped EXOS Token", "wEXOS") {}
}