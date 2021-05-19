// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '../abstracts/Pausable.sol';

import '../interfaces/IStakeToken.sol';
import '../interfaces/IStakeManager.sol';
import '../interfaces/IStakingV1.sol';
import '../interfaces/IStakingV2.sol';

contract StakeUpgrader is Manageable, Migrateable, Pausable {
    /** Structs / Vars ------------------------------------------------------------------- */
    struct Settings {
        bool maxShareEventActive;
        uint16 maxShareMaxDays;
        uint32 secondsInDay;
        uint32 lastSessionIdV2;
        uint32 lastSessionIdV1;
    }

    struct Contracts {
        IStakeToken stakeToken;
        IStakeManager stakeManager;
        IStakingV2 stakingV2;
        IStakingV1 stakingV1;
    }

    Settings internal settings;
    Contracts internal contracts;

    /** @dev Max Share Upgrade
        Description: function that allows a stake to be upgraded to a stake with a length of 5555 days without incuring any penalties
        the function takes the current earned interest and uses the principal + interest to create a new stake
        for v2 stakes it's only updating the current existing stake info, it's not creating a new stake
        @param sessionId {uint256} - id of the staking session

        Modifier: Pausable
    */
    function maxShareUpgrade(uint256 sessionId) external pausable {
        require(
            contracts.stakeToken.ownerOf(sessionId) == msg.sender,
            'UPGRADER: Not owner of stake.'
        );

        StakeData memory stake = contracts.stakeManager.getStake(sessionId);

        require(stake.shares != 0, 'STAKING: Stake withdrawn or not set');

        maxShareUpgradeInternal(stake.stakingDays);

        contracts.stakeManager.upgradeExistingStake(sessionId);
    }

    /** @dev Max Share Legacy Upgrade
        Description: similar to the maxShare function, but for layer 1 stakes only
        @param sessionId {uint256} - id of the staking session
    */
    function maxShareLegacyUpgrade(uint256 sessionId) external pausable {
        require(sessionId <= settings.lastSessionIdV2, 'UNSTAKER: invalid stakeId.');
        require(contracts.stakeToken.exists(sessionId) == false, 'UNSTAKER: stake is v3.');
        require(
            contracts.stakeManager.getStakeWithdrawn(sessionId) == false,
            'UNSTAKER: stake is withdrawn.'
        );

        // first check if saved in v2
        (
            uint256 amount,
            uint256 start,
            uint256 end,
            uint256 shares,
            uint256 firstInterestDay,
            ,
            bool withdrawn,

        ) = contracts.stakingV2.sessionDataOf(msg.sender, sessionId);

        if (shares != 0) {
            // if shares are not 0 it means it is v2 or has been upgraded and saved to v2

            require(withdrawn == false, 'UNSTAKER: stake withdrawn on v2.');
        } else {
            require(sessionId <= settings.lastSessionIdV1, 'UNSTAKER: invalid stakeId.');
            // otherwise check in v1 if valid v1 id

            (amount, start, end, shares, firstInterestDay) = contracts.stakingV1.sessionDataOf(
                msg.sender,
                sessionId
            );

            require(shares != 0, 'UNSTAKER: stake withdrawn on v1.');
        }

        uint256 stakingDays = (end - start) / settings.secondsInDay;

        maxShareUpgradeInternal(stakingDays);

        contracts.stakeManager.upgradeExistingLegacyStake(
            sessionId,
            firstInterestDay,
            shares,
            amount,
            start,
            stakingDays
        );
    }

    /** @dev Max Share Upgrade Interal
        Description: Function to calculate the new start, end, new amount and new shares for a max share upgrade
        @param stakingDays {uint256}
    */
    function maxShareUpgradeInternal(uint256 stakingDays) internal view {
        require(settings.maxShareEventActive == true, 'STAKING: Max Share event is not active');
        require(
            stakingDays <= settings.maxShareMaxDays,
            'STAKING: Max Share Upgrade - Stake must be less then max share max days'
        );
    }

    /** @dev Set Max Share Event Active
        @param _active {bool}
     */
    function setMaxShareEventActive(bool _active) external onlyManager {
        settings.maxShareEventActive = _active;
    }

    /** @dev Set Max share max days
        @param _maxShareMaxDays {bool}
     */
    function setMaxShareMaxDays(uint16 _maxShareMaxDays) external onlyManager {
        settings.maxShareMaxDays = _maxShareMaxDays;
    }

    /** Getters -------------------------------------------------------------------- */
    function getMaxShareEventActive() external view returns (bool) {
        return settings.maxShareEventActive;
    }

    function getMaxShareMaxDays() external view returns (uint16) {
        return settings.maxShareMaxDays;
    }

    /** Initialize ------------------------------------------------------------------------ */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _stakeManager,
        address _stakeToken,
        address _stakingV2,
        address _stakingV1
    ) public onlyMigrator {
        contracts.stakeManager = IStakeManager(_stakeManager);
        contracts.stakeToken = IStakeToken(_stakeToken);
        contracts.stakingV2 = IStakingV2(_stakingV2);
        contracts.stakingV1 = IStakingV1(_stakingV1);
    }

    function restore(
        bool _maxShareEventActive,
        uint16 _maxShareMaxDays,
        uint32 _secondsInDay,
        uint32 _lastSessionIdV2,
        uint32 _lastSessionIdV1
    ) external onlyMigrator {
        settings.maxShareEventActive = _maxShareEventActive;
        settings.maxShareMaxDays = _maxShareMaxDays;
        settings.secondsInDay = _secondsInDay;
        settings.lastSessionIdV2 = _lastSessionIdV2;
        settings.lastSessionIdV1 = _lastSessionIdV1;
    }
}