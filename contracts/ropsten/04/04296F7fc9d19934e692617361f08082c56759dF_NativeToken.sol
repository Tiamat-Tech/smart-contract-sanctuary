// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NativeToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("NativeToken", "NT") {
        _mint(msg.sender, initialSupply * (10**18));
    }
}