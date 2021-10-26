// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


import "./ERC20.sol";
import "./Ownable.sol";

contract Dai is ERC20,Ownable {
    
    
    constructor() ERC20("DAI TOKen", "DAI") {}
    
    
    function Faucet(address recipient,uint _amount) external {
        
        _mint(recipient,_amount * (10 ** 18));
    }
    
    
}