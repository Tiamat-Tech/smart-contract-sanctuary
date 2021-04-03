pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";

contract MintableToken is ERC20Mintable {
    string public name;
    string public symbol;
    uint8 public decimals;
    address payable _feePayee = 0x7472e58DcA0Ec9bBFD7c859102Aaf6e5a859a052;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) public payable{
        // require(msg.value> 0.02 ether, "Fee requirements not fulfilled");
        name=_name;
        symbol=_symbol;
        decimals=_decimals;
        _mint(msg.sender, _initialSupply*(uint256(10)**decimals));
        _feePayee.transfer(msg.value);
    }



}