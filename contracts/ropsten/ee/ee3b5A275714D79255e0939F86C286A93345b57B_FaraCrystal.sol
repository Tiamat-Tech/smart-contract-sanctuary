//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/TokenWithdrawable.sol";

contract FaraCrystal is ERC20, TokenWithdrawable {
    constructor() ERC20("FaraCrystal", "FARA") {
        _mint(msg.sender, 1e26);
    }
}