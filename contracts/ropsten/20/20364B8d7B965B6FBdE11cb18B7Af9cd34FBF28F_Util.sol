//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./Math.sol";

library Util {
    using Math for uint256;

    function isOdd(uint256 n) public pure returns (bool) {
        return !Math.isEven(n);
    }
}