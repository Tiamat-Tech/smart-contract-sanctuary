// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockWETH is ERC20{
    constructor(uint _initialSupply) ERC20("Mock WETH","mWETH"){
        _mint(msg.sender,_initialSupply * 10 ** decimals());
    }
}