// contracts/Minecoin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Minecoin is ERC777 {
    constructor(uint256 initialSupply, address[] memory defaultOperators) 
        ERC777("Minecoin", "MCN", defaultOperators) {
            _mint(msg.sender, initialSupply, "", "");
        }
}