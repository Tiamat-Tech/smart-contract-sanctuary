pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SandyToken is ERC20 {
    constructor(uint initialSupply) ERC20('SandyToken','SAND1'){
        _mint(msg.sender,initialSupply);
    }
}