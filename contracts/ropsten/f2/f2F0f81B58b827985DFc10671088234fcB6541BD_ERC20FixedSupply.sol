pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol';

contract ERC20FixedSupply is ERC20, ERC20Detailed("Cryptid (plural Cryptids)", "CRYPTID", 18) {
    constructor() public {
        _mint(msg.sender, 22000000000000000000000000);
    }
}