/// SPDX-License-Identifier: MIT
/// Maze Protocol Contracts v1.0.0 (Maze.sol)

pragma solidity ^0.8.0;

import "./auction/AuctionCore.sol";

contract Maze is AuctionCore {
    // Initialize maze protocol contract
    function initialize(address _feeReceiver, address _wbtm) public initializer {
        feeReceiver = _feeReceiver;
        wbtm = _wbtm;
    }

    // Pause maze protocol contract
    function pause() public onlyOwner whenNotPaused {
        super._pause();
    }

    // Override unpause so it requires all external contract addresses
    function unpause() public onlyOwner whenPaused {
        require(feeReceiver != address(0), "fee receiver is not ready.");
        require(wbtm != address(0), "wrapped btm contract is not ready.");
        // Actually unpause the contract.
        super._unpause();
    }
}