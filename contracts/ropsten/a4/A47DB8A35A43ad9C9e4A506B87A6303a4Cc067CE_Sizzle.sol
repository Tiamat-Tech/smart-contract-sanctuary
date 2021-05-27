// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.7.6 <0.9.0;

library SignedMath {
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? b : a;
    }
}