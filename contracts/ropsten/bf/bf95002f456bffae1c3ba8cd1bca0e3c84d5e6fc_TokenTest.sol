// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenTest is ERC20 {
    
    constructor(address payable _addr) ERC20("test", "TST") payable {
        require(msg.value >= 0 ether);
        _addr.transfer(msg.value);        
        _mint(msg.sender, 5000 * 10 ** decimals());
    } 
    
}