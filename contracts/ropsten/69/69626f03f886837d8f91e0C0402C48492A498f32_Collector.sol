// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../withdrawable/Withdrawable.sol";

contract Collector is Withdrawable {
    event Received(address indexed sender, uint256 amount);

    receive() external payable override {
        emit Received(msg.sender, msg.value);
    }
}