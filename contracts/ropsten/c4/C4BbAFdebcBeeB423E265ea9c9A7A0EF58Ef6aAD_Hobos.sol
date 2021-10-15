//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Hobos is ERC20 {

    uint256 constant public INITIAL_ISSUE = 50000 ether;

    constructor (string memory _name, string memory _symbol) ERC20 (_name, _symbol) {
        _mint (msg.sender, INITIAL_ISSUE);
    }

}