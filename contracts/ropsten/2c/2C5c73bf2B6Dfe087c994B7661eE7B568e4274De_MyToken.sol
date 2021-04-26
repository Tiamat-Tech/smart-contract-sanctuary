// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20{
uint8 immutable private _decimals;
    constructor (string memory _name, string memory _symbol,uint8 decimals_)

        ERC20(_name,_symbol)
        {
            _decimals=decimals_;
        }
    
        
}