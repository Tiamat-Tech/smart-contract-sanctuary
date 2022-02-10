// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VSM is ERC20, Ownable {
    constructor() ERC20("VSM_ERC20", "VSM_ERC20_01") {
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}