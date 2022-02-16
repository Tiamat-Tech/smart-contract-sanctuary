// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

contract Token is ERC20, Ownable {
    uint public maxSupply;
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 1000*10**18);
        maxSupply = 1000*10**18;
    }

    function mint(address to, uint amount) public onlyOwner {  
        require(maxSupply - totalSupply() >= amount, "exceeded maxsupply limit");
        _mint(to, amount);
    }

    function burn(address to, uint amount) public onlyOwner {
        _burn(to, amount);
    }
}