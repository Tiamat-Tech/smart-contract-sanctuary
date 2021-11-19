pragma solidity ^0.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract token1 is ERC20 {
    constructor(uint256 initialSupply) public ERC20("Baghii", "BGH") {
        _mint(msg.sender, initialSupply * (10**18));
        _setupDecimals(0);
    }
}