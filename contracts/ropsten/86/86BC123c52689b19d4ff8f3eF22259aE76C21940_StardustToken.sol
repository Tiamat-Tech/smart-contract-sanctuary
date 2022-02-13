// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StardustToken is ERC20("Stardust Token", "Stardust"), Ownable{
    constructor(){
    }
    function mint(address to, uint256 amount) public onlyOwner{
        _mint(to, amount);
    }
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}