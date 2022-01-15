//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.2;

import "./ERC777/ERC777.sol";
import "./ProxyAdmin.sol";
import "./Pausable.sol";

contract KombatToken is ERC777{


    constructor(uint256 initialSupply, address[] memory defaultOperators)
        ERC777("KOmbat", "KMBT", defaultOperators)
    {
        _mint(msg.sender, 25000000000, "", "");
    }
}