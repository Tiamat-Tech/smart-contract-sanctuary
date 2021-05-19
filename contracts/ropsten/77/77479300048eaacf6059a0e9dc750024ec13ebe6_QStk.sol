// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * Quiver Stock Contract
 * @author fantasy
 *
 * total supply on contact creation.
 * blacklisted users can't make any action and QStk balance.
 */

contract QStk is OwnableUpgradeable, ERC20Upgradeable {
    event AddBlacklistedUser(address indexed _user);
    event RemoveBlacklistedUser(address indexed _user);

    mapping(address => bool) public isBlacklisted;

    function initialize(uint256 _totalSupply) external initializer {
        __Ownable_init();
        __ERC20_init("Quiver Stock", "QSTK");

        _mint(msg.sender, _totalSupply);
    }

    function addBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] != true, "QStk: already in blacklist");

        isBlacklisted[_user] = true;

        emit AddBlacklistedUser(_user);
    }

    function removeBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] == true, "QStk: not in blacklist");

        isBlacklisted[_user] = false;
        _burn(_user, balanceOf(_user));

        emit RemoveBlacklistedUser(_user);
    }

    // Internal functions

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        if (_from == address(0)) {
            // mint
        } else if (_to == address(0)) {
            // burn
        } else {
            // blacklisted users can't transfer tokens
            require(
                isBlacklisted[_from] != true,
                "QStk: sender address is in blacklist"
            );
            require(
                isBlacklisted[_to] != true,
                "QStk: target address is in blacklist"
            );
            require(_amount != 0, "QStk: non-zero amount is required");
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}