pragma solidity ^0.8.0;

import './extensions/ERC20Burnable.sol';

contract Finhaven is ERC20Burnable{
	/**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    ) ERC20(name, symbol) {
        _mint(owner, initialSupply);
    }
}