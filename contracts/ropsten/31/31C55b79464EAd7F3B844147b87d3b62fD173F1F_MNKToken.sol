// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract MNKToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("ManekiToken", "MNK") {
        _mint(msg.sender, initialSupply);
    }

    function close() public onlyOwner {
        selfdestruct(msg.sender);
    }
}