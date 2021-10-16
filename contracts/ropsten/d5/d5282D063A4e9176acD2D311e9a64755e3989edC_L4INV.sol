//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract L4INV is ERC20, ERC20Burnable, Ownable, ERC20Permit {

    uint256 private constant SUPPLY = 100_000_000 * 10**18;
    
    constructor() ERC20("L4INV Token", "L4INV") ERC20Permit("L4INV")  {
        _mint(msg.sender, SUPPLY);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    } 
}