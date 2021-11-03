// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Implementation of mPUNDIX token.
 */
contract mPUNDIX is ERC20 {
    /**
     * @dev Initializes the contract
     */
    constructor() ERC20("mPUNDIX", "mPUNDIX") {
        _mint(msg.sender, 10e18);
    }
}