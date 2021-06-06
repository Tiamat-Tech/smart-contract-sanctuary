// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract MNKToken is ERC20, Ownable {
    uint256 private value;

    constructor(uint256 initialSupply) ERC20("ManekiToken", "MNK") {
        _mint(msg.sender, initialSupply * (10**18));
    }

    // function retrieve() public view returns (string memory) {
    //     return name();
    // }

    // event ValueChanged(uint256 newValue);

    // // The onlyOwner modifier restricts who can call the store function
    // function store(uint256 newValue) public onlyOwner {
    //     value = newValue;
    //     emit ValueChanged(newValue);
    // }

    /// for testing purpose, will be deleted when deployed to
    /// mainnet
    function close() public onlyOwner {
        selfdestruct(msg.sender);
    }
}