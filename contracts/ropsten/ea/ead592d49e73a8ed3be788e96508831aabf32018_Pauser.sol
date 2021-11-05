//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IPausableByPauser} from "../interfaces/IPausableByPauser.sol";
import {IPauser} from "../interfaces/IPauser.sol";

/**
 * @title Pauser Contract
 * @notice Pauses and unpauses all vaults, vault configs, strategies and rewards
 * in case of emergency.
 * Note: Owner is a multi-sig wallet.
 */
contract Pauser is IPauser, OwnableUpgradeable {
    mapping(address => bool) public isRegistered;

    // vaults
    address[] public vaults;
    // vault configs
    address[] public vaultConfigs;
    // strategies
    address[] public strategies;
    // rewards
    address[] public rewards;

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function pauseAll() external override onlyOwner {
        for (uint256 i; i < vaults.length; i++) {
            try IPausableByPauser(vaults[i]).pause() {} catch {
                continue;
            }
        }
        for (uint256 i; i < vaultConfigs.length; i++) {
            try IPausableByPauser(vaultConfigs[i]).pause() {} catch {
                continue;
            }
        }
        for (uint256 i; i < strategies.length; i++) {
            try IPausableByPauser(strategies[i]).pause() {} catch {
                continue;
            }
        }
        for (uint256 i; i < rewards.length; i++) {
            try IPausableByPauser(rewards[i]).pause() {} catch {
                continue;
            }
        }
        emit PausedAll(_msgSender());
    }

    function unpauseAll() external override onlyOwner {
        for (uint256 i; i < vaults.length; i++) {
            try IPausableByPauser(vaults[i]).unpause() {} catch {
                continue;
            }
        }
        for (uint256 i; i < vaultConfigs.length; i++) {
            try IPausableByPauser(vaultConfigs[i]).unpause() {} catch {
                continue;
            }
        }
        for (uint256 i; i < strategies.length; i++) {
            try IPausableByPauser(strategies[i]).unpause() {} catch {
                continue;
            }
        }
        for (uint256 i; i < rewards.length; i++) {
            try IPausableByPauser(rewards[i]).unpause() {} catch {
                continue;
            }
        }
        emit UnpausedAll(_msgSender());
    }

    function getVaults() external view override returns (address[] memory) {
        return vaults;
    }

    function getVaultConfigs() external view override returns (address[] memory) {
        return vaultConfigs;
    }

    function getStrategies() external view override returns (address[] memory) {
        return strategies;
    }

    function getRewards() external view override returns (address[] memory) {
        return rewards;
    }

    function pushVault(address addr) external override onlyOwner notZeroAddress(addr) {
        if (isRegistered[addr]) return;
        vaults.push(addr);
        isRegistered[addr] = true;
    }

    function pushVaultConfig(address addr) external override onlyOwner notZeroAddress(addr) {
        if (isRegistered[addr]) return;
        vaultConfigs.push(addr);
        isRegistered[addr] = true;
    }

    function pushStrategy(address addr) external override onlyOwner notZeroAddress(addr) {
        if (isRegistered[addr]) return;
        strategies.push(addr);
        isRegistered[addr] = true;
    }

    function pushRewards(address addr) external override onlyOwner notZeroAddress(addr) {
        if (isRegistered[addr]) return;
        rewards.push(addr);
        isRegistered[addr] = true;
    }

    function removeVault(address addr) external override onlyOwner notZeroAddress(addr) {
        if (!isRegistered[addr]) return;
        for (uint256 i; i < vaults.length; i++) {
            if (addr == vaults[i]) {
                vaults[i] = vaults[vaults.length - 1];
                vaults.pop();
                isRegistered[addr] = false;
                return;
            }
        }
    }

    function removeVaultConfig(address addr) external override onlyOwner notZeroAddress(addr) {
        if (!isRegistered[addr]) return;
        for (uint256 i; i < vaultConfigs.length; i++) {
            if (addr == vaultConfigs[i]) {
                vaultConfigs[i] = vaultConfigs[vaultConfigs.length - 1];
                vaultConfigs.pop();
                isRegistered[addr] = false;
                return;
            }
        }
    }

    function removeStrategy(address addr) external override onlyOwner notZeroAddress(addr) {
        if (!isRegistered[addr]) return;
        for (uint256 i; i < strategies.length; i++) {
            if (addr == strategies[i]) {
                strategies[i] = strategies[strategies.length - 1];
                strategies.pop();
                isRegistered[addr] = false;
                return;
            }
        }
    }

    function removeReward(address addr) external override onlyOwner notZeroAddress(addr) {
        if (!isRegistered[addr]) return;
        for (uint256 i; i < rewards.length; i++) {
            if (addr == rewards[i]) {
                rewards[i] = rewards[rewards.length - 1];
                rewards.pop();
                isRegistered[addr] = false;
                return;
            }
        }
    }

    modifier notZeroAddress(address addr) {
        require(addr != address(0), "contract address is 0");
        _;
    }
}