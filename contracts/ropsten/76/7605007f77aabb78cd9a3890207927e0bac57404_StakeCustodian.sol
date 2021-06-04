// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '../abstracts/Migrateable.sol';
import '../abstracts/ExternallyCallable.sol';

import '../interfaces/IStakeCustodian.sol';

import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

contract StakeCustodian is IStakeCustodian, Migrateable, ExternallyCallable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    mapping(address => EnumerableSetUpgradeable.UintSet) internal stakesOf;

    function addStake(address account, uint256 stakeId)
        external
        override
        onlyExternalCaller
        returns (bool)
    {
        return stakesOf[account].add(stakeId);
    }

    function removeStake(address account, uint256 stakeId)
        external
        override
        onlyExternalCaller
        returns (bool)
    {
        return stakesOf[account].remove(stakeId);
    }

    function isOwnerOfStake(address account, uint256 stakeId)
        external
        view
        override
        onlyExternalCaller
        returns (bool)
    {
        return stakesOf[account].contains(stakeId);
    }

    function initialize(
        address _migrator,
        address _stakeMinter,
        address _stakeBurner,
        address _stakeUpgrader
    ) external initializer {
        _setupRole(MIGRATOR_ROLE, _migrator);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeMinter);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeBurner);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeUpgrader);
    }

    function getStakeIdsOf(address account) external view returns (uint256[] memory) {
        uint256[] memory stakeIds = new uint256[](stakesOf[account].length());

        for (uint256 i = 0; i < stakesOf[account].length(); i++) {
            stakeIds[i] = stakesOf[account].at(i);
        }

        return stakeIds;
    }
}