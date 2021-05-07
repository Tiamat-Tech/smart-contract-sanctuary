// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RandomToken is ERC20("Random Token", "RND") {    
    constructor () public {
        _mint(msg.sender, 1_000_000_000 ether);
    }
}