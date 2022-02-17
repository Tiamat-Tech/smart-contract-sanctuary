// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Number is Ownable {
    uint256 public number;

    function setNumber(uint256 _number) public onlyOwner {
        number = _number;
    }
}