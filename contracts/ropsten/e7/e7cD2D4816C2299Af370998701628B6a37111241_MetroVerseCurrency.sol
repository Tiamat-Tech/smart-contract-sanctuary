//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../utils/TokenWithdrawable.sol";

contract MetroVerseCurrency is ERC20, ERC20Burnable, TokenWithdrawable {
    constructor() ERC20("MetroVerse Currency", "MVC") {
        _mint(msg.sender, 5e26);
    }
}