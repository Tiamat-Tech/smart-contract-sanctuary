pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCoin is ERC20 {
    uint public currentSupply;
    
    constructor(uint _initialSupply) ERC20("TestCoin", "TC") { 
        currentSupply = _initialSupply;
    }

    function mint(uint amount) external {
        require(currentSupply > 0);
        _mint(msg.sender, amount);
        currentSupply -= amount;
    }
}