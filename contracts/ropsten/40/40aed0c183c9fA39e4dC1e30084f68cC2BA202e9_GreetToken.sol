//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./../utils/TokenWithdrawable.sol";


contract GreetToken is ERC20, TokenWithdrawable {
    constructor() ERC20("Greet Token", "GRT") {
        _mint(_msgSender(), 1e24);
    }
}