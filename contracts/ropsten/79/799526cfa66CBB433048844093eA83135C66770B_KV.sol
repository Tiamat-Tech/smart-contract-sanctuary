//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

struct Value {
    bytes data;
    address owner;
}

contract KV {
    mapping (bytes32 => Value) public data;

    constructor() {
    }

    function set(bytes32 key, bytes memory value) public {
        require(data[key].owner == msg.sender || data[key].owner == address(0x0));
        data[key].data = value;
        data[key].owner = msg.sender;
    }

    function get(bytes32 key) public view returns (bytes memory) {
        return data[key].data;
    }
}