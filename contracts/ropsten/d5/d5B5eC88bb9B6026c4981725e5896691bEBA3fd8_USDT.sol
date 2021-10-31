// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


import "./ERC20.sol";
import "./Ownable.sol";

contract USDT is ERC20,Ownable {
    
    
    constructor() ERC20("Tether USDT", "USDT") {}
    
    
    // faucet
    
    
    function Mint(address recipient,uint _amount) external {
        
        _mint(recipient,_amount * (10 ** decimals()));
    }
    
    // decimals

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    
    
   
    
    
}