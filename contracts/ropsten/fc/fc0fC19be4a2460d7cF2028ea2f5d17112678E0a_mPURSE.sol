// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Implementation of mPURSE token.
 */
contract mPURSE is ERC20 {
    /**
     * @dev Initializes the contract
     */
    constructor() ERC20("mPURSE", "mPURSE") {
        _mint(msg.sender, 10e18);
    }
}