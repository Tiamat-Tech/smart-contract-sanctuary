// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// mock class using ERC20
contract ERC20Mock is ERC20 {
    constructor (
    ) payable ERC20("mock", "mck") {
        _mint(msg.sender, 1000000000000000000000);
    }


    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }


    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }


    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }


    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}