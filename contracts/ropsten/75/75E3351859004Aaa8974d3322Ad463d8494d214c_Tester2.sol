// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Tester2 is Ownable {
    address public a;
    constructor(address _a){
        a = _a;
    }
}