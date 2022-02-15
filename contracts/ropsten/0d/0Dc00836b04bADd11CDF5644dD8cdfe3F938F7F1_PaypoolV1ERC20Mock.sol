// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../PaypoolV1ERC20.sol";

contract PaypoolV1ERC20Mock is PaypoolV1ERC20 {

    function mint(uint256 amount) override external {
        return _mint(msg.sender, amount);
    }

    function mintTo(address to, uint256 amount) override external {
        return _mint(to, amount);
    }
}