//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Adminable.sol";

contract Random is Adminable {
    uint256 inc = 1;

    function roll(address player) public isAdmin returns(uint8){
        uint256 result = uint(keccak256(abi.encodePacked(block.timestamp/1000, block.timestamp%1000, player, inc)));
        inc = inc + 1;
        return uint8((result % 6)+1);
    }

    function rollResult(uint8 value, address player) public returns(bool){
        //faire le Random
        uint8 result = roll(player);
        return result == value;
    }

    function grantAdmin(address newAdmin) public isAdmin {
        admin[newAdmin] = 1;
    }

    function revokeAdmin(address oldAdmin) public isAdmin {
        admin[oldAdmin] = 0;
    }
}