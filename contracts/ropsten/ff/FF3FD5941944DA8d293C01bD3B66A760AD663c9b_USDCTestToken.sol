// contracts/USDCTestToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./lib/openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * For testing token with 6 decimals
 * @title USDCTestToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 * Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/examples/SimpleToken.sol
 */
contract USDCTestToken is ERC20 {
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function mintTo(address destination, uint256 amount) external {
        _mint(destination, amount);
    }
}