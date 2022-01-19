//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//string memory name_, string memory symbol_
contract ERC20MockContract is ERC20 {
    constructor()
        ERC20("Mock ERC20", "MER")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}