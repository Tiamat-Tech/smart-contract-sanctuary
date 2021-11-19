pragma solidity ^0.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract token2 is ERC20 {
    constructor(uint256 initialSupply) public ERC20("OreGairu", "SAD") {
        _mint(msg.sender, initialSupply);
        _setupDecimals(0);
    }
}