// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./MyToken.sol";

contract MyTokenV2 is MyToken {
    function version() public pure virtual override returns(uint256) {
        return 2;
    }
}