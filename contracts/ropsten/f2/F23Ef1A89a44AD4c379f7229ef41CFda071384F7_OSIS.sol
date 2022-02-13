// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @custom:security-contact [email protected]
contract OSIS is ERC20 {
    constructor() ERC20("OSIS", "OSIS") {
        _mint(msg.sender, 100000000 * 10 ** decimals ());
    }
}