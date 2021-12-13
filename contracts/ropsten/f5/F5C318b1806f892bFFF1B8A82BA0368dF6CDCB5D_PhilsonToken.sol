// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol"; 

contract PhilsonToken is ERC20  {
    constructor() ERC20("Philson Token", "PHIL") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}