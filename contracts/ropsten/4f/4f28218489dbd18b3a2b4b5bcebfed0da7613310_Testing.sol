// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Testing is Ownable {
    constructor() {}
    
    function getTimep() public view onlyOwner returns (uint256) {
        return block.timestamp;
    }
}