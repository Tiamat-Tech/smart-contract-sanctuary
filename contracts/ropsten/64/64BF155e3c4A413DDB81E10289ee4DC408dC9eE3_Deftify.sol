// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Deftify is ERC20, Ownable {
    uint8 decimals_;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {
        decimals_ = _decimals;
        _mint(msg.sender, _totalSupply * (10**_decimals));
        transferOwnership(msg.sender);
    }

    function decimals() public view override returns (uint8) {
        return decimals_;
    }
}