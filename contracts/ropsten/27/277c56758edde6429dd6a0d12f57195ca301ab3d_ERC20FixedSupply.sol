pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

contract ERC20FixedSupply is ERC20 , ERC20Detailed{
    constructor(string memory name, string memory symbol, uint8 decimals, uint256 _initialSupply) ERC20Detailed(name, symbol, decimals) public payable  {
        _mint(msg.sender, _initialSupply*(uint8(10)**decimals));
    }
}