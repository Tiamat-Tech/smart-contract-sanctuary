// contracts/TestCoin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract TestCoin is ERC777, Ownable {
    constructor(address[] memory defaultOperators)
        ERC777("TestCoin", "TestCoin", defaultOperators)
    {}

    function mint(
        uint256 amount,
        bytes memory reason,
        bytes memory extraData
    ) public onlyOwner returns (bool success) {
        _mint(msg.sender, amount, reason, extraData);
        return true;
    }
}