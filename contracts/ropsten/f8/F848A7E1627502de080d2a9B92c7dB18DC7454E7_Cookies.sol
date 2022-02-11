// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ICookieClicker.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Cookies is ERC20, Ownable {

    ICookieClicker public Clicker;

    constructor(address game) ERC20("Cookies", "CUK") {
        Clicker = ICookieClicker(game);
        _mint(game, type(uint256).max);
        Clicker.setCookiesContract(address(this));
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        if(msg.sender != address(Clicker)) {
            super._spendAllowance(owner, spender, amount);
        }
    }

    function balanceOf(address account) public view override returns(uint256) {
        return super.balanceOf(account) + Clicker.viewPendingCookiesRewardForUser(account);
    }
}