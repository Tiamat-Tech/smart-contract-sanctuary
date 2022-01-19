// contracts/SimpleToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 * Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/examples/SimpleToken.sol
 */
contract Tokenche is ERC20 {
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
         uint256 initialSupply;
        uint256 _totalSupply;
    constructor(uint256 initialSupply) public ERC20("Tokenche", "TO") {
        _totalSupply=10000000000;
        initialSupply=1000000;
        _mint(msg.sender, initialSupply);
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
}