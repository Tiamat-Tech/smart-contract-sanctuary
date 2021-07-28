// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SwapAndLiquifyV3.sol";

// Import previous contract and update it
contract SwapAndLiquifyProxyV3 is SwapAndLiquifyV3 {
   
    function getTokenAddress() public view returns(address) {
        return (ggrtAddress);
    }
}