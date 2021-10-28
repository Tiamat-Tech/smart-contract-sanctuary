// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol';

contract MZR is ERC20{
    constructor() ERC20('Mizar', 'MZR') {
        _mint(msg.sender, 10_000_000_000 * 10 ** 18);
    }
    
    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }
}