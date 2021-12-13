// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.0 <=0.8.9;

import "./BurnableToken.sol";

contract WBTC is BurnableToken {
    constructor() {
        _initialize("Wrapped BTC for Skybridge", "WBTC", 8, 0, true);
    }
}