// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Tester is Ownable {
    uint public c;
    constructor(){
        c = 5;
    }
    function test() public view returns(uint){
        return c + 1;
    }
    function test2(uint cc) public{
        c += cc;
    }

}