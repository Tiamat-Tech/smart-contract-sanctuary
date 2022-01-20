// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockedToken is ERC20 {

    constructor() ERC20("MockedToken", "MT") {
        _mint(msg.sender, 500000 * 10 ** decimals());
    }

    function faucet() external {
        _mint(msg.sender, 100 * 10 ** decimals());
    }
}