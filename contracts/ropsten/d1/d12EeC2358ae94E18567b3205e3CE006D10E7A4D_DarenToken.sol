// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract DarenToken is ERC20Upgradeable, AccessControlEnumerableUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function initialize() public initializer {
        __ERC20_init("Daren Token", "DT");
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);

        uint256 defaultSupply = 5 *
            1000 *
            1000 *
            1000 * /*decimals*/
            (1000 * 1000) *
            (1000 * 1000) *
            (1000 * 1000);
        _mint(msg.sender, defaultSupply);
    }

    function zeng(address account, uint256 amount) public onlyRole(ADMIN_ROLE) {
        _mint(account, amount);
    }

    function shao(address account, uint256 amount) public onlyRole(ADMIN_ROLE) {
        _burn(account, amount);
    }
}