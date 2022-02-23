// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./MyTokenV2.sol";

contract MyTokenV3 is MyTokenV2 {
    function version() public pure virtual override returns(uint256) {
        return 3;
    }
}