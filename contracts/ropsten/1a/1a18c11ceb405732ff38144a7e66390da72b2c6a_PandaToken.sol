// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract PandaToken is ERC20Upgradeable {
    function initialize() initializer public {
        __ERC20_init("Panda Token", "PT");
        _mint(_msgSender(), 10000000000 * 10 ** decimals());
    }
}