// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
contract ERMToken is ERC20{
constructor(uint256 initialSupply,string memory name_, string memory symbol_, uint8 decimal_) 
public 
ERC20(name_, symbol_) {
        _setupDecimals(decimal_);
        _mint(msg.sender, initialSupply * (10** uint256(decimal_)));
    }
}