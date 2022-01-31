//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.2;

import "./ERC777/ERC777.sol";
import "./Pausable.sol";



contract KombatToken is ERC777{
    
    constructor(address[] memory defaultOperators)
        ERC777("KOmbats", "KMBTB", defaultOperators)
    {
        _mint(msg.sender, 25000000000000*10**18, "", "");
    }
    
}