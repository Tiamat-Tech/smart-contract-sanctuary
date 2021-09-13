// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC20PresetPreMint.sol";

contract RHZToken is ERC20PresetPreMint {

    /**
     * @dev Contract description
     */
    string public info;

    constructor() ERC20PresetPreMint("RHZ Token", "RHZ", 10000) {
        info = "Example RHZ Token";
    }

}