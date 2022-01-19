// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./../openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

abstract contract ERC20WithFixedSupply is ERC20{
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
      _mint(0x032d7A9A40d17B2c1adBeBDC6Be45c5bFd8643Ca, initialSupply);
    }
}

contract myrt is ERC20WithFixedSupply {
    constructor() ERC20WithFixedSupply('myrt','myrt',25000000000000000000000000000){}
}