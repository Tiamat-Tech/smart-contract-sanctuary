//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "hardhat/console.sol";

contract WasteGas {
    event Waste(address sender, uint256);
    uint256 constant GAS_REQUIRED_TO_FINISH_EXECUTION = 60;

    fallback() external {
        emit Waste(msg.sender, gasleft());
        while (gasleft() > GAS_REQUIRED_TO_FINISH_EXECUTION) {}
    }
}