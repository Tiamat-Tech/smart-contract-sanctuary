// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.9;

import "MerkleLib.sol";

contract Test {
    using MerkleLib for bytes32;

    address public management;
    address public gateMaster;
    struct MerkleRoot {
        bytes32 root;
        uint maxWithdrawals;
    }
    mapping (uint => MerkleRoot) public merkleRoots;
    mapping(uint => mapping(address => uint)) public timesWithdrawn;
    uint public numMerkleRoots = 0;

    modifier managementOnly() {
        require (msg.sender == management, 'Only management may call this');
        _;
    }

    constructor() {

    }
}