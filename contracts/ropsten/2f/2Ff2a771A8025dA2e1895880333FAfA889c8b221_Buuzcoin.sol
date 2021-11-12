// contracts/Buuzcoin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract Buuzcoin is ERC777 {
    // Initial supply of Buuzcoins
    uint256 public constant INITIAL_SUPPLY = 10_000_000_000_000 * 10**18;

	constructor(address[] memory defaultOperators)
        ERC777("Buuzcoin", "BZC", defaultOperators)
    {
        _mint(msg.sender, INITIAL_SUPPLY, "", "");
    }
}