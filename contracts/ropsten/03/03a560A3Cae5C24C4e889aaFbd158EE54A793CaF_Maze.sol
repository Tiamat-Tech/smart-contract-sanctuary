/// SPDX-License-Identifier: MIT
/// Maze Protocol Contracts v1.0.0 (Maze.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./auction/AuctionCore.sol";

contract Maze is AuctionCore, IERC721Receiver {
    constructor() {
        // starts paused.
        pause();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    /// Pause maze protocol contract.
    function pause() public onlyOwner whenNotPaused {
        super._pause();
    }

    /// @dev Override unpause so it requires all external contract addresses
    function unpause() public onlyOwner whenPaused {
        require(feeReceiver != address(0), "fee receiver is not ready.");
        // Actually unpause the contract.
        super._unpause();
    }
}