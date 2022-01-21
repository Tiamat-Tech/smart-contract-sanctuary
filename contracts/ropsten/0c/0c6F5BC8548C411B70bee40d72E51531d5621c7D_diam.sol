// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract diam is Context, Ownable, ERC20 {

    constructor() ERC20("DIAM", "DIAM") {
        _mint(_msgSender(), 10000000000000000000000000000);
    }

}