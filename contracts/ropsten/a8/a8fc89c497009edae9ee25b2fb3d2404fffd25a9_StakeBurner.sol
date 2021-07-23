// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';

import '../abstracts/Pausable.sol';
import '../abstracts/ExternallyCallable.sol';

import '../interfaces/IStakeBurner.sol';
import '../interfaces/IBpd.sol';
import '../interfaces/IToken.sol';
import '../interfaces/IAuction.sol';
import '../interfaces/IStakeToken.sol';
import '../interfaces/IStakeManager.sol';
import '../interfaces/IStakeCustodian.sol';
import '../interfaces/IStakingV1.sol';
import '../interfaces/IStakingV21.sol';

contract StakeBurner is IStakeBurner, Manageable, Migrateable, Pausable, ExternallyCallable {
    struct Settings {
        uint32 secondsInDay;
        uint32 lastSessionIdV2;
        uint32 lastSessionIdV1;
        uint32 bpdDayRange; //350 days, time of the first BPD
    }

    struct Contracts {
        IBpd bpd;
        IToken token;
        IAuction auction;
        IStakeToken stakeToken;
        IStakeManager stakeManager;
        IStakeCustodian stakeCustodian;
        IStakingV1 stakingV1;
        IStakingV21 stakingV2;
    }

    Settings internal settings;
    Contracts internal contracts;

    /** @dev unstake function
        Description: Unstake and burn NFT
        @param sessionId {uint256} - Id of stake
     */
    function burnStake(uint256 sessionId) external pausable {
        burnStakeInternal(sessionId, msg.sender);
    }

    /** @dev External Burn stake
        Description: Allow external to unstake
        @param sessionId {uint256}
        @param staker {address}

        Modifier: onlyExternalCaller, Pausable
     */
    function externalBurnStake(uint256 sessionId, address staker)
        external
        override
        onlyExternalCaller
        pausable
        returns (uint256)
    {
        return burnStakeInternal(sessionId, staker);
    }

    /** @dev Burn Stake Internal
        Description: Common functionality for unstaking
        @param sessionId {uint256}
        @param staker {address}
     */
    function burnStakeInternal(uint256 sessionId, address staker) internal returns (uint256) {
        require(
            contracts.stakeToken.isOwnerOf(staker, sessionId) ||
                contracts.stakeCustodian.isOwnerOf(staker, sessionId),
            'STAKE BURNER: Not owner of stake.'
        );

        (uint256 start, uint256 stakingDays, uint256 amount, uint256 shares, uint256 interest) =
            contracts.stakeManager.getStakeAndInterestById(sessionId);

        uint256 payout =
            handlePayoutAndPenalty(staker, interest, amount, start, stakingDays, shares);
        contracts.stakeManager.unsetStake(staker, sessionId, payout);

        return payout;
    }

    /** @dev Unstake Legacy
        Description: unstake function for layer1 stakes
        @param sessionId {uint256} - id of the layer 1 stake

        @return {uint256}
    */
    function unstakeLegacyStake(uint256 sessionId) external pausable returns (uint256) {
        return unstakeLegacyStakeInternal(sessionId, msg.sender, false);
    }

    /** @dev Unstake Legacy
        Description: unstake function for layer1 stakes
        @param sessionId {uint256} - id of the layer 1 stake
        @param staker {uint256} - Stake owner
        @param requireMature {bool} - ?

        @return {uint256}

        Modifiers: OnlyExternalCaller, Pauasable
    */
    function externalLegacyUnstake(
        uint256 sessionId,
        address staker,
        bool requireMature
    ) external override onlyExternalCaller pausable returns (uint256) {
        return unstakeLegacyStakeInternal(sessionId, staker, requireMature);
    }

    /** @dev Unstake Legacy
        Description: Internal functionality for unstake functions
        @param sessionId {uint256} - id of the layer 1 stake
        @param staker {uint256} - Stake owner
        @param requireMature {bool} - ?

        @return {uint256}

        Modifiers: OnlyExternalCaller, Pauasable
    */
    function unstakeLegacyStakeInternal(
        uint256 sessionId,
        address staker,
        bool requireMature
    ) internal returns (uint256) {
        require(sessionId <= settings.lastSessionIdV2, 'STAKE BURNER: invalid stakeId.');
        require(
            contracts.stakeManager.getStakeWithdrawnOrExists(sessionId) == false,
            'STAKE BURNER: stake is withdrawn or already v3.'
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

        ) = contracts.stakingV2.sessionDataOf(staker, sessionId);

        if (shares != 0) {
            if (requireMature) {
                require(
                    end != 0 && end <= block.timestamp,
                    'STAKE BURNER: stake not mature or not set.'
                );
            }
            // if shares are not 0 it means it is v2 or has been upgraded and saved to v2

            require(withdrawn == false, 'STAKE BURNER: stake withdrawn on v2.');
        } else {
            require(sessionId <= settings.lastSessionIdV1, 'STAKE BURNER: invalid stakeId.');
            // otherwise check in v1 if valid v1 id
            (amount, start, end, shares, firstInterestDay) = contracts.stakingV1.sessionDataOf(
                staker,
                sessionId
            );

            if (requireMature) {
                require(
                    end != 0 && end <= block.timestamp,
                    'STAKE BURNER: stake not mature or not set.'
                );
            }

            require(shares != 0, 'STAKE BURNER: stake withdrawn on v1.');
        }

        uint256 stakingDays = (end - start) / settings.secondsInDay;

        uint256 interest =
            contracts.stakeManager.getStakeInterest(firstInterestDay, stakingDays, shares);

        uint256 payout =
            handlePayoutAndPenalty(staker, interest, amount, start, stakingDays, shares);

        contracts.stakeManager.unsetLegacyStake(
            staker,
            sessionId,
            shares,
            amount,
            start,
            firstInterestDay,
            stakingDays,
            payout
        );
        // Add to stake custodian as the v1 or v2 stake is now a v3 stake that has been withdrawn
        contracts.stakeCustodian.addStake(staker, sessionId);

        return payout;
    }

    /** @dev Get Payout and Penalty
        Description: calculate the amount the stake earned and any penalty because of early/late unstake
        @param amount {uint256} - amount of AXN staked
        @param start {uint256} - start date of the stake
        @param stakingDays {uint256}
        @param stakingInterest {uint256} - interest earned of the stake
    */
    function getPayoutAndPenaltyInternal(
        uint256 amount,
        uint256 start,
        uint256 stakingDays,
        uint256 stakingInterest
    ) internal view returns (uint256, uint256) {
        uint256 stakingSeconds = stakingDays * settings.secondsInDay;
        uint256 secondsStaked = block.timestamp - start;
        uint256 daysStaked = secondsStaked / settings.secondsInDay;
        uint256 amountAndInterest = amount + stakingInterest;

        // Early
        if (stakingDays > daysStaked) {
            uint256 payOutAmount = (amountAndInterest * secondsStaked) / stakingSeconds;

            uint256 earlyUnstakePenalty = amountAndInterest - payOutAmount;

            return (payOutAmount, earlyUnstakePenalty);
            // In time
        } else if (daysStaked < stakingDays + 14) {
            return (amountAndInterest, 0);
            // Late
        } else if (daysStaked < stakingDays + 714) {
            return (amountAndInterest, 0);
            /** Remove late penalties for now */

            // uint256 daysAfterStaking = daysStaked - stakingDays;

            // uint256 payOutAmount =
            //     amountAndInterest.mul(uint256(714).sub(daysAfterStaking)).div(
            //         700
            //     );

            // uint256 lateUnstakePenalty = amountAndInterest.sub(payOutAmount);

            // return (payOutAmount, lateUnstakePenalty);
        } else {
            return (0, amountAndInterest);
        }
    }

    /** @dev Handle Payout and Penalty
        Description: Generate payout and mint tokens to staker
        @param staker {address}
        @param interest {uint256}
        @param amount {uint256}
        @param start {uint256}
        @param stakingDays {uint256}
        @param shares {uint256}
     */
    function handlePayoutAndPenalty(
        address staker,
        uint256 interest,
        uint256 amount,
        uint256 start,
        uint256 stakingDays,
        uint256 shares
    ) internal returns (uint256) {
        if (stakingDays >= settings.bpdDayRange) {
            uint256 intendedEnd = start + (uint256(settings.secondsInDay) * stakingDays);

            interest += contracts.bpd.getBpdAmount(
                shares,
                start,
                block.timestamp < intendedEnd ? block.timestamp : intendedEnd
            );
        }

        (uint256 payout, uint256 penalty) =
            getPayoutAndPenaltyInternal(amount, start, stakingDays, interest);

        if (payout != 0) {
            contracts.token.mint(staker, payout);
        }

        if (penalty != 0) {
            contracts.auction.addTokensToNextAuction(penalty);
        }

        return payout;
    }

    /** Initialize ------------------------------------------------------------------ */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _bpd,
        address _token,
        address _auction,
        address _stakeToken,
        address _stakeReminter,
        address _stakeManager,
        address _stakeCustodian,
        address _stakingV1,
        address _stakingV2
    ) public onlyMigrator {
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeReminter);

        contracts.bpd = IBpd(_bpd);
        contracts.token = IToken(_token);
        contracts.auction = IAuction(_auction);
        contracts.stakeToken = IStakeToken(_stakeToken);
        contracts.stakeManager = IStakeManager(_stakeManager);
        contracts.stakeCustodian = IStakeCustodian(_stakeCustodian);
        contracts.stakingV2 = IStakingV21(_stakingV2);
        contracts.stakingV1 = IStakingV1(_stakingV1);
    }

    function restore(
        uint32 _secondsInDay,
        uint32 _lastSessionIdV2,
        uint32 _lastSessionIdV1
    ) external onlyMigrator {
        settings.secondsInDay = _secondsInDay;
        settings.lastSessionIdV2 = _lastSessionIdV2;
        settings.lastSessionIdV1 = _lastSessionIdV1;
    }

    /** @dev Get Payout and Penalty 
        Description: Calls internal function, this will allow frontend to generate payout as well
        @param amount {uint256} - amount of AXN staked
        @param start {uint256} - start date of the stake
        @param stakingDays {uint256}
        @param stakingInterest {uint256} - interest earned of the stake
    */
    function getPayoutAndPenalty(
        uint256 amount,
        uint256 start,
        uint256 stakingDays,
        uint256 stakingInterest
    ) external view returns (uint256, uint256) {
        return getPayoutAndPenaltyInternal(amount, start, stakingDays, stakingInterest);
    }

    function getSettings() external view returns (Settings memory) {
        return settings;
    }
}