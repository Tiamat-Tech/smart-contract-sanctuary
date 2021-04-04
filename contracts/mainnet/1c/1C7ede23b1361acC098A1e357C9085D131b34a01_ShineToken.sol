pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract ShineToken is ERC20, ERC20Detailed,ERC20Burnable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) public ERC20Detailed(name, symbol, 18) {
        _mint(msg.sender, initialSupply);
    }
}