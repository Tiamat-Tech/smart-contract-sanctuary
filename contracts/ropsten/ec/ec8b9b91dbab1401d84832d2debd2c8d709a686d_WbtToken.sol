// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Managable.sol";

contract WbtToken is ERC20Managable {
    constructor() ERC20Managable("WhiteBIT WBT", "WBT", 18, 400000000000000000000000000) {
    }
}