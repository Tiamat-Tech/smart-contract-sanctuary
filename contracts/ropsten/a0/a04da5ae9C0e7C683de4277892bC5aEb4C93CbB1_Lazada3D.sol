// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";

contract Lazada3D is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Lazada3D", "laz") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}