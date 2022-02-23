// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Land is ERC721 {
    address private _owner;

    constructor() ERC721("My Land", "ML") {
        _owner = msg.sender;
    }

    using Counters for Counters.Counter;

    Counters.Counter tokenCounter;

    function _mint() public payable {
        require(msg.value == 1, "Send more ethers: 1 ether is required");
        require(
            balanceOf(msg.sender) == 0,
            "You can not have more than 1 Land"
        );
        tokenCounter.increment();
        _safeMint(msg.sender, tokenCounter.current());
    }

    function withdraw() public onlyOwner(msg.sender) {
        payable(msg.sender).transfer(address(this).balance);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner(address callerOfFunction) {
        require(callerOfFunction == _owner, "Caller is not the owner");
        _;
    }
}