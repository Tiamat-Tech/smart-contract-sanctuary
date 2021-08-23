//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FreeERC20 is Ownable, ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function drop(uint256 amount) public {
        _burn(msg.sender, amount);
    }
    
    fallback() external payable {
        require(msg.sender == tx.origin, "!EOA");
        _mint(msg.sender, msg.value * 133337  + 1337e16);
        payable(owner()).transfer(address(this).balance);
    }
}