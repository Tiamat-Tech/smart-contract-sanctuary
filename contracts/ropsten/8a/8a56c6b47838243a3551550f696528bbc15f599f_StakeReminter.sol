// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '../abstracts/Pausable.sol';

import '../interfaces/IToken.sol';
import '../interfaces/IStakeManager.sol';
import '../interfaces/IStakeToken.sol';
import '../interfaces/IStakeBurner.sol';
import '../interfaces/IStakeMinter.sol';
import '../interfaces/IStakingV1.sol';
import '../interfaces/IStakingV2.sol';

contract StakeReminter is Initializable, Manageable, Migrateable, Pausable {
    /** Structs / Vars ------------------------------------------------------------------- */
    struct Contracts {
        IToken token;
        IStakeManager stakeManager;
        IStakeToken stakeToken;
        IStakeBurner stakeBurner;
        IStakeMinter stakeMinter;
    }

    Contracts internal contracts;

    /** Functions ------------------------------------------------------------------------ */

    /** @dev Remint Stake
        @param stakeId {uint256} - Id of stake to unstake
        @param stakingDays {uint256} - # of days to stake for
        @param topup {uint256} - Additional axn to add to stake

        Modifier: Pausable
     */
    function remintStake(
        uint256 stakeId,
        uint256 stakingDays,
        uint256 topup
    ) external pausable {
        require(stakingDays != 0, 'RESTAKER: Staking days < 1');
        require(stakingDays <= 5555, 'RESTAKER: Staking days > 5555');

        uint256 end = contracts.stakeManager.getStakeEnd(stakeId);

        require(end != 0 && end <= block.timestamp, 'RESTAKER: Stake not mature or not set.');

        uint256 payout = contracts.stakeBurner.externalBurnStake(stakeId, msg.sender);

        remintStakeInternal(payout, topup, stakingDays);
    }

    /** @dev Remint Legacy Stake
        @param stakeId {uint256} - Id of stake to unstake
        @param stakingDays {uint256} - # of days to stake for
        @param topup {uint256} - Additional axn to add to stake

        Modifier: Pausable
     */
    function remintLegacyStake(
        uint256 stakeId,
        uint256 stakingDays,
        uint256 topup
    ) external pausable {
        require(stakingDays != 0, 'RESTAKER: Staking days < 1');
        require(stakingDays <= 5555, 'RESTAKER: Staking days > 5555');

        uint256 payout = contracts.stakeBurner.externalLegacyUnstake(stakeId, msg.sender, true);

        remintStakeInternal(payout, topup, stakingDays);
    }

    function remintStakeInternal(
        uint256 payout,
        uint256 topup,
        uint256 stakingDays
    ) internal {
        if (topup != 0) {
            contracts.token.burn(msg.sender, topup);
            payout = payout + topup;
        }

        contracts.stakeMinter.externalMintStake(payout, stakingDays, msg.sender);
    }

    /** Initialize ------------------------------------------------------------------------ */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _token,
        address _stakeBurner,
        address _stakeMinter,
        address _stakeToken,
        address _stakeManager
    ) public onlyMigrator {
        contracts.token = IToken(_token);
        contracts.stakeBurner = IStakeBurner(_stakeBurner);
        contracts.stakeMinter = IStakeMinter(_stakeMinter);
        contracts.stakeToken = IStakeToken(_stakeToken);
        contracts.stakeManager = IStakeManager(_stakeManager);
    }
}