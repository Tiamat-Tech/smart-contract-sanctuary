// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../openzeppelin/contracts/access/Ownable.sol";

contract TestMule is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Test Mule", "MULE") {
        _mint(msg.sender, 7884203284 * 10 ** decimals());
    }

}