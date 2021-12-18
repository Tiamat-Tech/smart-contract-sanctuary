//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AbobaToken is ERC20Upgradeable, OwnableUpgradeable {
    function initialize() external initializer {
        __ERC20_init("ABOBA", "ABOBA");
        __Ownable_init_unchained();
        _mint(_msgSender(), 1000 * 10**18);
    }
}