// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract MyToken is ERC20, Ownable {

    address public contractAddress = 0x8b9eA0fA38c593fa1b574dC0AABFB85DD6486755;
    constructor() ERC20("MyToken", "MTK") {}

    


    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}