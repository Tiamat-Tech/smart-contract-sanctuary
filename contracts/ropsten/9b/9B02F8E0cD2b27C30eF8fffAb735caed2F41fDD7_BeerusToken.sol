// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BeerusToken is ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    function initialize() initializer public {
        __ERC20_init("Beerus", "BEE");
     }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}