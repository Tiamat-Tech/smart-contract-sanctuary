// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAIMock is ERC20 {
    constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        mintArbitrary(msg.sender, 1000000000000000000000);
    }

    function mintArbitrary(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}