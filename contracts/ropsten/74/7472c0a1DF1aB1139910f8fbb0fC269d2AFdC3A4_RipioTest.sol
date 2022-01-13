// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/draft-ERC20Permit.sol";

contract RipioTest is ERC20, Ownable, ERC20Permit {
    constructor() ERC20("Ripio Test", "RTEST") ERC20Permit("Ripio Test") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}