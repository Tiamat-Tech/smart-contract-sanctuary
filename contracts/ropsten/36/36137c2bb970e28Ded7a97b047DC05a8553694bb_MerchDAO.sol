// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MerchDAO is ERC20("MerchDAO", "MRCH"), Ownable {
    
    uint public constant TOTAL_SUPPLY = 10000000 * (10 ** 18);
    
    constructor() public {    
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}