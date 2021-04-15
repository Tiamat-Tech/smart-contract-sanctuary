pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract WAVEToken is ERC20, ERC20Burnable {
    constructor(uint256 initialSupply) ERC20("Wave Token", "WAVE") {
        _mint(msg.sender, initialSupply);
    }
}