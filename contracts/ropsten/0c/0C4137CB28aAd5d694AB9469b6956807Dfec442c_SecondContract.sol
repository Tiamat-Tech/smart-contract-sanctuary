// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;
import "./FirstContract.sol";

contract SecondContract {
    // Attempts to call FirstContract.protected
    // It calls from a contract and hence fails

    function access(address _target) external {
        // The following function call will fail
        FirstContract(_target).protected();
    }

}