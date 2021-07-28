// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "../openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract FireToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    function initialize() initializer public {
        __ERC20_init("Fire Token", "FIRE");
        __ERC20Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, 2000100999 * 10 ** decimals());
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}