// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract History is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable {
    function initialize() initializer public {
        __ERC20_init("History", "HSY");
        __ERC20Burnable_init();
        _mint(msg.sender, (10 ** 9) * (10 ** 9));
    }

    function decimals() public view override returns (uint8) {
        return 9;
    }
}