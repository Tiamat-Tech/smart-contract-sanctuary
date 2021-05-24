// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Bit2Me", "B2M") {
        _mint(msg.sender, 5000000000 ether);
    }
}