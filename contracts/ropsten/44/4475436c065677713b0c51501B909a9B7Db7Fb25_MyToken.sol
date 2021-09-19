// SPDX-License-Identifier: MIT
// https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable
// https://simpleaswater.com/upgradable-smart-contracts/
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MyToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __ERC20_init("MyToken", "MTK");
        __ERC20Burnable_init();

        _mint(msg.sender, 10000000 * 10**decimals());
    }
}