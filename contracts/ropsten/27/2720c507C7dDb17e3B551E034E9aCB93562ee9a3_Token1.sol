pragma solidity =0.7.6;


import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token1 is ERC20 {
    constructor(uint256 initialSupply) ERC20("Token1", "TK1") {
        _mint(msg.sender, initialSupply);
    }
}