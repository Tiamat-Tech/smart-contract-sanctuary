//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20{
    address public admin;
    uint amountReceived;

    constructor() ERC20('MyToken', 'MTN') {
        _mint(msg.sender, 10000 * 10 ** 18);
        admin = msg.sender;
    }
    function mint(address to, uint amount) external {
        require(msg.sender == admin, 'only admin');
        _mint(to, amount);
    }
    function burn(uint amount) external{
        _burn(msg.sender, amount);
    }
    function MaxSupply(address recipient, uint amount) public {
        amountReceived = (amount  * 60) / 100;
        _transfer(msg.sender, recipient, amountReceived);
    }
   function MaxSupplyPrivate(address recipient, address administrator, uint amount) public{
       require( msg.sender == administrator, 'only admin' );
       amountReceived = (amount  * 40) / 100;
       _transfer(msg.sender, recipient, amountReceived);
   }
    
}