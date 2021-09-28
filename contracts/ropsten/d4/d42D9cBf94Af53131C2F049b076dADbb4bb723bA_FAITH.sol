pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title FAITH
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 * Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/examples/SimpleToken.sol
 */
contract FAITH is ERC20 {
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    string public _name = "FAITH";
    string public _symbol = "FATE";
    uint256 public _initialSupply = 10**9 * 10**18;
    constructor() ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply);
    }
}