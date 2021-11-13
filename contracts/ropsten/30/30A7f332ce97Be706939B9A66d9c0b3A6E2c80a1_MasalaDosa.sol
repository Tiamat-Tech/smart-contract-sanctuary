// contracts/MasalaDosa.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract MasalaDosa is ERC777 {
    //constructor(uint256 initialSupply, address[] memory defaultOperators)
    constructor(uint256 initialSupply)
        ERC777("MasalaDosa", "MSD", new address[](0))
    {
        _mint(msg.sender, initialSupply, "", "");
    }
}