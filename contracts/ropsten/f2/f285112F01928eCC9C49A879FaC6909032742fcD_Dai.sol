// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


import "./ERC20.sol";
import "./Ownable.sol";

contract Dai is ERC20,Ownable {
    
    
    constructor() ERC20("DAI TOKen", "DAI") {}
    
    
    function Faucet(address recipient,uint _amount) external {
        
        _mint(recipient,_amount);
    }
    
    
}


//  0xf285112F01928eCC9C49A879FaC6909032742fcD -- d


// 0x4F9CA1bEe86dbBB7eA6E6554932089888E8E2D70 -- f