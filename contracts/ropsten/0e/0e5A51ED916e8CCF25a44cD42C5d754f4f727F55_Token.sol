pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    
    address internal owner;
    constructor(string memory _name, string memory _tkn, uint _supply) ERC20(_name, _tkn){
        owner = msg.sender;
        
        _mint(msg.sender, _supply);
    }
    
}