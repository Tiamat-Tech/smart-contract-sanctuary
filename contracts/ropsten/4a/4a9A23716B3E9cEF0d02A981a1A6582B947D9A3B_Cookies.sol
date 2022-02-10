// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Cookies is ERC20, Ownable {

    address immutable _GAME_;

    constructor(address game) ERC20("Cookies", "CUK") {
        _GAME_ = game;
        _mint(game, type(uint256).max);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        if(msg.sender != _GAME_) {
            super._spendAllowance(owner, spender, amount);
        }
    }
}