// SPDX-License-Identifier: UNLICENSED

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

pragma solidity ^0.8.0;

contract RewardToken is ERC20 {

    constructor (uint _initialSupply)  ERC20("RewardToken", "RT")   {
        _mint(msg.sender, _initialSupply*10**18);
        
    }

    
    
}