pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./interfaces/IPriceFeed.sol";

contract Stablecoin is ERC20 {
    IPriceFeed public priceFeed;
    
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor (string memory _name, string memory _symbol, uint256 initialSupply, uint8 _decimals, address oracle) public {
        require(initialSupply != 0);
        require(oracle != address(0));

        name = _name;
        symbol = _symbol;
        decimals =  _decimals;

        _totalSupply = initialSupply;

        priceFeed = IPriceFeed(oracle);
    }

    function issue() public payable {
        uint amount = (msg.value * priceFeed.getPrice()) / 1 ether;
        
        _totalSupply += amount;
        balances[msg.sender] += amount;
    }

    function withdraw(uint _amount) public payable {
        require(_amount >= balances[msg.sender]);

        uint256 amount = (_amount * 1 ether) / priceFeed.getPrice();
        
        balances[msg.sender] -= amount;
        _totalSupply -= amount;

        msg.sender.transfer(amount);
    }
}