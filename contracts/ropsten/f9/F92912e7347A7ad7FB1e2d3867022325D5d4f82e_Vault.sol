// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Detailed} from "./interfaces/IERC20Detailed.sol";
import {VaultStorage} from "./VaultStorage.sol";

contract Vault is OwnableUpgradeable, PausableUpgradeable, ERC20PermitUpgradeable, VaultStorage {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(address token_) public initializer {
        __Ownable_init();
        __Pausable_init();
        string memory name = string(abi.encodePacked(IERC20Detailed(token_).name(), " sVault"));
        string memory symbol = string(abi.encodePacked("sv", IERC20Detailed(token_).symbol()));
        __ERC20_init(name, symbol);
        __ERC20Permit_init("Swift Vault");

        token = IERC20Upgradeable(token_);
    }

    // ERC20Upgradeable

    function decimals() public override view virtual returns (uint8) {
        return IERC20Detailed(address(token)).decimals();
    }

    // Vault

    function deposit(uint256 amount) external {
    }

    function depositAll() external {
    }

    function withdraw(uint256 shares) external {
    }

    function withdrawAll() external {
    }
}