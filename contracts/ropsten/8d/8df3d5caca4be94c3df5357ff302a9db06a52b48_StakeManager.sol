// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
// Base
import '../base/StakeBase.sol';
// OpenZeppelin
import '@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
// Interfaces
import '../interfaces/IStakeManager.sol';

import '../libs/AxionSafeCast.sol';

contract StakeManager is IStakeManager, StakeBase {
    using AxionSafeCast for uint256;
    using SafeCastUpgradeable for uint256;
    /* Contract Variables ---------------------------------------------------------------------------------------*/

    BpdPool internal bpd;
    Settings internal settings;
    Contracts internal contracts;
    StatFields internal statFields;
    InterestFields internal interestFields;

    uint256[] public interestPerShare;

    mapping(uint256 => StakeData) internal stakeData;

    //mapping(uint256 => bool) internal stakeWithdrawn; - might use later if we set stake values to 0

    /* Set Stakes ------------------------------------------------------------------------------------------------*/

    /** Set New Stake
        Description: Add stake to database
        @param staker {address} - Address of staker to add new stake for (Users can stake for eachother?)
        @param amount {uint256} - Amount to stake / burn from wallet
        @param stakingDays {uint256} - Length of stake
    */
    function createStake(
        address staker,
        uint256 amount,
        uint256 stakingDays
    ) external override onlyExternalCaller returns (uint256) {
        statFields.lastStakeId++;

        uint256 shares = getStakersSharesAmount(amount, stakingDays);

        addToGlobalTotals(amount, shares);
        createStakeInternal(
            NewStake({
                id: statFields.lastStakeId,
                amount: amount,
                shares: shares,
                start: block.timestamp,
                stakingDays: stakingDays
            })
        );

        contracts.vcAuction.addTotalSharesOfAndRebalance(staker, shares);

        if (stakingDays >= settings.bpdDayRange) {
            addBpdShares(shares, block.timestamp, stakingDays);
        }

        emit StakeCreated(
            staker,
            statFields.lastStakeId,
            stakeData[statFields.lastStakeId].amount,
            stakeData[statFields.lastStakeId].shares,
            stakeData[statFields.lastStakeId].start,
            stakeData[statFields.lastStakeId].stakingDays
        );

        return statFields.lastStakeId;
    }

    function addBpdShares(
        uint256 shares,
        uint256 start,
        uint256 stakingDays
    ) internal {
        uint256 end = start + (stakingDays * settings.secondsInDay);
        uint16[2] memory bpdInterval = getBpdInterval(start, end);

        for (uint16 i = bpdInterval[0]; i < bpdInterval[1]; i++) {
            bpd.shares[i] += shares.toUint128(); // we only do integer shares, no decimals
        }
    }

    /** Set Exiting Stake
        Description: Upgrade existing stake from L1/L2 into Layer3
        @param amount {uint256} # of axion for stake
        @param shares {uint256} # of shares of current stake
        @param start {uint256} Start of stake in seconds
        @param end {uint256} - End of stake in seconds
        @param id {uint256} - Previous ID should be <= lastSessionId2
     */
    function createExistingStake(
        uint256 amount,
        uint256 shares,
        uint256 start,
        uint256 end,
        uint256 id
    ) external override onlyExternalCaller {
        uint256 stakingDays = (end - start) / settings.secondsInDay;

        /** No need to call addToGlobalTotals since they should already be included */
        createStakeInternal(
            NewStake({
                id: id,
                amount: amount,
                shares: shares,
                start: start,
                stakingDays: stakingDays
            })
        );

        emit ExistingStakeCreated(
            id,
            stakeData[id].amount,
            stakeData[id].shares,
            stakeData[id].start,
            stakeData[id].stakingDays
        );
    }

    /** Upgrade Existing Stake
        Description: Upgrade existing stake layer 3 with max shares (5555 day stake)
        @param id {uint256} - ID should be less then LastSessionIdV3

        Modifier: OnlyExternalCaller - Can only be called by StakeUpgrader
     */
    function upgradeExistingStake(uint256 id) external override onlyExternalCaller {
        upgradeExistingStakeInternal(
            StakeUpgrade({
                id: id,
                firstInterestDay: stakeData[id].firstInterestDay,
                shares: stakeData[id].shares,
                amount: stakeData[id].amount,
                start: stakeData[id].start,
                stakingDays: stakeData[id].stakingDays
            })
        );
    }

    /** Upgrade Existing Stake
        Description: Bring existing stake into layer 3 with max shares (5555 day stake)
        @param id {uint256} - ID should be less then LastSessionIdV3
        @param firstInterestDay {uint256}
        @param shares - Shares of old stake
        @param amount - Amount of old stake
        @param start - Start of old stake
        @param stakingDays {uint256}

        Modifier: OnlyExternalCaller - Can only be called by StakeUpgrader
     */
    function upgradeExistingLegacyStake(
        uint256 id,
        uint256 firstInterestDay,
        uint256 shares,
        uint256 amount,
        uint256 start,
        uint256 stakingDays
    ) external override onlyExternalCaller {
        upgradeExistingStakeInternal(
            StakeUpgrade({
                id: id,
                firstInterestDay: firstInterestDay,
                shares: shares,
                amount: amount,
                start: start,
                stakingDays: stakingDays
            })
        );
    }

    /** Upgrade Existing Stake Internal (Common)
        Description: Internal reusable components for upgrading Stake
        @param stakeUpgrade {StakeUpgrade} Input Struct
     */
    function upgradeExistingStakeInternal(StakeUpgrade memory stakeUpgrade) internal {
        uint256 newAmount =
            getStakeInterestInternal(
                stakeUpgrade.firstInterestDay,
                stakeUpgrade.stakingDays,
                stakeUpgrade.shares
            ) + stakeUpgrade.amount;

        uint256 intendedEnd =
            stakeUpgrade.start + (settings.secondsInDay * stakeUpgrade.stakingDays);

        // We use "Actual end" so that if a user tries to withdraw their BPD early they don't get the shares
        if (stakeUpgrade.stakingDays >= settings.bpdDayRange) {
            uint16[2] memory bpdInterval =
                getBpdInterval(
                    stakeUpgrade.start,
                    block.timestamp < intendedEnd ? block.timestamp : intendedEnd
                );
            newAmount += getBpdAmount(stakeUpgrade.shares, bpdInterval);
        }

        uint256 newShares = getStakersSharesAmount(newAmount, stakeUpgrade.stakingDays);

        require(
            newShares > stakeUpgrade.shares,
            'STAKING: New shares are not greater then previous shares'
        );

        uint256 newEnd = block.timestamp + (settings.secondsInDay * 5555);

        addBpdMaxShares(
            stakeUpgrade.shares,
            stakeUpgrade.start,
            stakeUpgrade.start + (settings.secondsInDay * stakeUpgrade.stakingDays),
            newShares,
            block.timestamp,
            newEnd
        );

        addToGlobalTotals(newAmount - stakeUpgrade.amount, newShares - stakeUpgrade.shares);

        createStakeInternal(
            NewStake({
                id: stakeUpgrade.id,
                amount: newAmount,
                shares: newShares,
                start: block.timestamp,
                stakingDays: 5555
            })
        );

        emit StakeUpgraded(
            msg.sender,
            stakeUpgrade.id,
            stakeData[stakeUpgrade.id].amount,
            newAmount,
            stakeData[stakeUpgrade.id].shares,
            newShares,
            block.timestamp,
            newEnd
        );
    }

    /** formula for shares calculation given a number of AXN and a start and end date
        @param amount {uint256} - amount of AXN
        @param stakingDays {uint256}
    */
    function getStakersSharesAmount(uint256 amount, uint256 stakingDays)
        internal
        view
        returns (uint256)
    {
        uint256 numerator = amount * (1819 + stakingDays);
        uint256 denominator = 1820 * interestFields.shareRate;

        return (numerator * 1e18) / denominator;
    }

    function addBpdMaxShares(
        uint256 oldShares,
        uint256 oldStart,
        uint256 oldEnd,
        uint256 newShares,
        uint256 newStart,
        uint256 newEnd
    ) internal {
        uint16[2] memory oldBpdInterval = getBpdInterval(oldStart, oldEnd);
        uint16[2] memory newBpdInterval = getBpdInterval(newStart, newEnd);

        for (uint16 i = oldBpdInterval[0]; i < newBpdInterval[1]; i++) {
            uint256 shares = newShares;

            if (oldBpdInterval[1] > i) {
                shares = shares - oldShares;
            }

            bpd.shares[i] += shares.toUint128(); // we only do integer shares, no decimals
        }
    }

    /** add to Global Totals
        @param amount {uint256}
        @param shares {uint256}
     */
    function addToGlobalTotals(uint256 amount, uint256 shares) internal {
        /** Set Global Variables */
        statFields.sharesTotalSupply += (shares / 1e12).toUint72();

        statFields.totalStakedAmount += (amount / 1e12).toUint72();

        statFields.totalVcaRegisteredShares += (shares / 1e12).toUint72();
    }

    /** Set Stake Internal
        @param stake {Stake} - Stake input
     */
    function createStakeInternal(NewStake memory stake) internal {
        //once a day we need to call makePayout which takes the interest earned for the last day and adds it into the payout array
        if (block.timestamp >= interestFields.nextAddInterestTimestamp) addDailyInterest();

        /** Set Stake data */
        stakeData[stake.id].amount = (stake.amount / 1e12).toUint64();
        stakeData[stake.id].shares = (stake.shares / 1e12).toUint64();
        stakeData[stake.id].start = stake.start.toUint40();
        stakeData[stake.id].stakingDays = stake.stakingDays.toUint16();
        stakeData[stake.id].firstInterestDay = interestPerShare.length.toUint24();
        stakeData[stake.id].status = StakeStatus.Active;
    }

    /* Unset Stakes ------------------------------------------------------------------------------------------------*/

    /** Unset Stake
        Description: Withdraw stake and close it out
        @param staker {address}
        @param id {uint256}

        Modifier: OnlyExternalCaller - Must be called by StakeBurner
     */
    function unsetStake(address staker, uint256 id)
        external
        override
        onlyExternalCaller
        returns (uint256, uint256)
    {
        (uint256 payout, uint256 penalty) =
            unsetStakeInternal(
                staker,
                id,
                stakeData[id].shares * 1e12,
                stakeData[id].amount * 1e12,
                stakeData[id].start,
                stakeData[id].firstInterestDay,
                stakeData[id].stakingDays
            );

        emit StakeDeleted(
            staker,
            id.toUint128(),
            stakeData[id].amount,
            stakeData[id].shares,
            stakeData[id].start,
            stakeData[id].stakingDays
        );

        // stake.amount = 0;
        // stake.shares = 0;
        // stake.start = 0;
        // stake.length = 0;
        // stake.firstInterestDay = 0;
        // might do this later

        stakeData[id].status = StakeStatus.Withdrawn; // same as = 0 but more explicit

        return (payout, penalty);
    }

    /** Unset Legacy Stake
        Description: Unset stake from l1/l2
        @param staker {address}
        @param id {uint256}
        @param shares {uint256}
        @param amount {uint256}
        @param firstInterestDay {uint256} - First day of interest since start of contract
        @param stakingDays {uint256}

        Modifier: OnlyExternalCaller - Must be called by StakeBurner
     */
    function unsetLegacyStake(
        address staker,
        uint256 id,
        uint256 shares,
        uint256 amount,
        uint256 start,
        uint256 firstInterestDay,
        uint256 stakingDays
    ) external override onlyExternalCaller returns (uint256, uint256) {
        (uint256 payout, uint256 penalty) =
            unsetStakeInternal(staker, id, shares, amount, start, firstInterestDay, stakingDays);

        stakeData[id].amount = (amount / 1e12).toUint64();
        stakeData[id].shares = (shares / 1e12).toUint64();
        stakeData[id].start = start.toUint40();
        stakeData[id].stakingDays = stakingDays.toUint16();
        stakeData[id].firstInterestDay = firstInterestDay.toUint24();
        // might remove this later

        return (payout, penalty);
    }

    /** Delete Stake Internal (Common)
        Description: Unset stakes common functinality function
        @param staker {address}
        @param id {uint256}
        @param shares {uint256}
        @param amount {uint256}
        @param firstInterestDay {uint256} - First day of interest since start of contract
        @param stakingDays {uint256} - Stake days

        Modifier: OnlyExternalCaller - Must be called by StakeBurner
     */
    function unsetStakeInternal(
        address staker,
        uint256 id,
        uint256 shares,
        uint256 amount,
        uint256 start,
        uint256 firstInterestDay,
        uint256 stakingDays
    ) internal returns (uint256, uint256) {
        require(
            stakeData[id].status != StakeStatus.Withdrawn,
            'STAKE MANAGER: Stake withdrawn already.'
        );

        //once a day we need to call makePayout which takes the interest earned for the last day and adds it into the payout array
        if (block.timestamp >= interestFields.nextAddInterestTimestamp) addDailyInterest();

        contracts.vcAuction.subTotalSharesOfAndRebalance(staker, shares);

        statFields.sharesTotalSupply -= (shares / 1e12).toUint72();

        statFields.totalStakedAmount -= (amount / 1e12).toUint72();

        statFields.totalVcaRegisteredShares -= (shares / 1e12).toUint72();

        uint256 interest = getStakeInterestInternal(firstInterestDay, stakingDays, shares);

        // We use "Actual end" so that if a user tries to withdraw their BPD early they don't get the shares
        if (stakingDays >= settings.bpdDayRange) {
            uint256 intendedEnd = start + (settings.secondsInDay * stakingDays);

            uint16[2] memory bpdInterval =
                getBpdInterval(
                    start,
                    block.timestamp < intendedEnd ? block.timestamp : intendedEnd
                );
            interest += getBpdAmount(shares, bpdInterval);
        }

        stakeData[id].payout = (interest / 1e18).toUint40();

        return getPayoutAndPenaltyInternal(amount, start, stakingDays, interest);
    }

    /** Get the interest earned for a particular stake.
        Description: staking interest calculation goes through the payout array and calculates the interest based on the number of shares the user has and the payout for every day
        @param firstInterestDay {uint256} - Beginning of stake days since start of contract
        @param stakingDays {uint256} - Stake days
        @param shares {uint256} - # of shares for stake
     */
    function getStakeInterestInternal(
        uint256 firstInterestDay,
        uint256 stakingDays,
        uint256 shares
    ) internal view returns (uint256) {
        uint256 lastInterest = 0;
        uint256 firstInterest = 0;
        uint256 lastInterestDay = firstInterestDay + stakingDays;

        if (interestPerShare.length != 0) {
            lastInterest = interestPerShare[
                MathUpgradeable.min(interestPerShare.length - 1, lastInterestDay - 1)
            ];
        }

        if (firstInterestDay != 0) {
            firstInterest = interestPerShare[firstInterestDay - 1];
        }

        return (shares * (lastInterest - firstInterest)) / (10**26);
    }

    function getBpdInterval(uint256 start, uint256 end) internal view returns (uint16[2] memory) {
        uint16[2] memory bpdInterval;
        uint256 denom = settings.secondsInDay * settings.bpdDayRange;

        bpdInterval[0] = uint16(
            MathUpgradeable.min(5, (start - settings.contractStartTimestamp) / denom)
        ); // (start - t0) // 350

        uint256 bpdEnd = uint256(bpdInterval[0]) + (end - start) / denom;

        bpdInterval[1] = MathUpgradeable.min(bpdEnd, 5).toUint16(); // bpd_first + nx350

        return bpdInterval;
    }

    function getBpdAmount(uint256 shares, uint16[2] memory bpdInterval)
        internal
        view
        returns (uint256)
    {
        uint256 bpdAmount;
        uint256 shares1e18 = shares * 1e18;

        for (uint16 i = bpdInterval[0]; i < bpdInterval[1]; i++) {
            bpdAmount += (shares1e18 / bpd.shares[i]) * bpd.pool[i];
        }

        return bpdAmount / 1e18;
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
        uint256 stakingSeconds = stakingDays * settings.secondsInDay - start;
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

    /** Interest ---------------------------------------------------------------------------- */

    /** Add Daily Interest
        Description: Runs once per day and takes all the AXN earned as interest and puts it into payout array for the day
    */
    function addDailyInterest() public {
        require(
            block.timestamp >= interestFields.nextAddInterestTimestamp,
            'Staking: Too early to add interest.'
        );

        uint256 todaysSharePayout;
        uint256 interest = getTodaysInterest(); // 179885952500978473581214

        if (interestPerShare.length != 0) {
            todaysSharePayout =
                interestPerShare[interestPerShare.length - 1] +
                ((interest * (10**26)) / ((statFields.sharesTotalSupply * 1e12) + 1));
        } else {
            // (179885952500978473581214 * 1e26) / ((481566159919219 * 1e12) + 1)

            todaysSharePayout = (interest * (1e26)) / ((statFields.sharesTotalSupply * 1e12) + 1);
        }
        // 37,354.359062761739399567
        interestPerShare.push(todaysSharePayout);

        interestFields.nextAddInterestTimestamp =
            interestFields.nextAddInterestTimestamp +
            settings.secondsInDay;

        //call updateShareRate once a day as sharerate increases based on the daily Payout amount
        // updateShareRate(interest);

        emit DailyInterestAdded(
            interest,
            statFields.sharesTotalSupply,
            todaysSharePayout,
            block.timestamp
        );
    }

    /** Get Todays Interest
        Description: Get # of circulating supply and total in stakemanager contract add 8% yearly
     */
    function getTodaysInterest() internal returns (uint256) {
        //todaysBalance - AXN from auction buybacks goes into the staking contract
        uint256 todaysBalance = contracts.token.balanceOf(address(this));

        uint256 currentTokenTotalSupply = contracts.token.totalSupply();

        contracts.token.burn(address(this), todaysBalance);

        // 820million axn / 8
        //we add 8% inflation
        uint256 inflation =
            (8 * (currentTokenTotalSupply + (statFields.totalStakedAmount * 1e12))) / 36500;

        // (8 * (718485214285714285714285714 + (102244444000000 * 1e12))) / 36500

        return todaysBalance + inflation; //179885952500978473581214
    }

    /** Update Share Rate
        Description: function to increase the share rate price
        the update happens daily and used the amount of AXN sold through regular auction to calculate the amount to increase the share rate with
        @param _payout {uint} - amount of AXN that was bought back through the regular auction + 8% yearly amount
    */
    function updateShareRate(uint256 _payout) internal {
        uint256 currentTokenTotalSupply = contracts.token.totalSupply(); // 718485214285714285714285714

        // (179885952500978473581214 * 1e18) / (718485214285714285714285714 + (481566159919219 * 1e12) + 1)

        uint256 growthFactor =
            (_payout * 1e18) /
                (currentTokenTotalSupply + (statFields.totalStakedAmount * 1e12) + 1); //we calculate the total AXN supply as circulating + staked

        // 149898542985426

        if (settings.shareRateScalingFactor == 0) {
            //use a shareRateScalingFactor which can be set in order to tune the speed of shareRate increase
            settings.shareRateScalingFactor = 1e18;
        }

        // (1091914945650513011 * ( 1e36 + 1e18 * 149898542985426)) / 1e36

        interestFields.shareRate = ((interestFields.shareRate *
            ((10**36) + (settings.shareRateScalingFactor) * growthFactor)) / 10**36)
            .toUint128(); //1e18 used for precision.
    }

    /** Utility ------------------------------------------------------------------ */

    /** Add Total VCA Registered Shares
        Description: Add to the total registered shares

        @param shares {uint256}
     */
    function addTotalVcaRegisteredShares(uint256 shares) external override onlyExternalCaller {
        statFields.totalVcaRegisteredShares += (shares / 1e12).toUint72();
    }

    /** BPD ---------------------------------------------------------------------- */
    function setBpdPools(uint128[5] calldata poolAmount, uint128[5] calldata poolShares)
        external
        onlyMigrator
    {
        for (uint8 i = 0; i < poolAmount.length; i++) {
            bpd.pool[i] = poolAmount[i];
            bpd.shares[i] = poolShares[i];
        }
    }

    /** Initialize ------------------------------------------------------------------------------------------------*/

    /** Upgradeable Initialize Function
        @param _manager {address} - Address for contract manager (Gnosis Wallet) 
        @param _migrator {address} - Address for contract migrator (Deployer Addres)
     */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _stakeMinter,
        address _stakeBurner,
        address _stakeUpgrader,
        address _token,
        address _vcAuction
    ) public onlyMigrator {
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeMinter);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeBurner);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeUpgrader);
        _setupRole(EXTERNAL_CALLER_ROLE, _vcAuction);

        contracts.token = IToken(_token);
        contracts.vcAuction = IVCAuction(_vcAuction);
    }

    function restore(
        uint128 _shareRateScalingFactor,
        uint32 _secondsInDay,
        uint64 _contractStartTimestamp,
        uint32 _bpdDayRange,
        uint128 _shareRate,
        uint128 _nextAddInterestTimestamp,
        uint72 _totalStakedAmount,
        uint72 _sharesTotalSupply,
        uint72 _totalVcaRegisteredShares,
        uint40 _lastStakeId
    ) external onlyMigrator {
        settings.shareRateScalingFactor = _shareRateScalingFactor;
        settings.secondsInDay = _secondsInDay;
        settings.contractStartTimestamp = _contractStartTimestamp;
        settings.bpdDayRange = _bpdDayRange;
        interestFields.shareRate = _shareRate;
        interestFields.nextAddInterestTimestamp = _nextAddInterestTimestamp;
        statFields.totalStakedAmount = _totalStakedAmount;
        statFields.sharesTotalSupply = _sharesTotalSupply;
        statFields.totalVcaRegisteredShares = _totalVcaRegisteredShares;
        statFields.lastStakeId = _lastStakeId;
    }

    function setBPDPools(uint128[5] calldata poolAmount, uint128[5] calldata poolShares)
        external
        onlyMigrator
    {
        for (uint8 i = 0; i < poolAmount.length; i++) {
            bpd.pool[i] = poolAmount[i];
            bpd.shares[i] = poolShares[i];
        }
    }

    function restorePayouts(uint256[] calldata payouts, uint256[] calldata shares)
        external
        onlyMigrator
    {
        require(payouts.length < 21, 'MANAGER: Sending to much data');
        require(payouts.length == shares.length, 'MANAGER: Payout.length != shares.length');

        uint256 todaysSharePayout;
        for (uint256 i = 0; i < payouts.length; i++) {
            uint256 interest = payouts[i];
            uint256 sharesTotalSupply = shares[i];

            if (interestPerShare.length != 0) {
                todaysSharePayout =
                    interestPerShare[interestPerShare.length - 1] +
                    ((interest * (10**26)) / ((sharesTotalSupply * 1e12) + 1));
            } else {
                todaysSharePayout = (interest * (10**26)) / ((sharesTotalSupply * 1e12) + 1);
            }

            interestPerShare.push(todaysSharePayout);
        }
    }

    /* Basic Setters ------------------------------------------------------------------------------------------------*/

    /** Set Interest Fields
        @param _shareRate {uint128}
        @param _nextAddInterestTimestamp {uint128}
     */
    function setInterestFields(uint128 _shareRate, uint128 _nextAddInterestTimestamp)
        external
        onlyMigrator
    {
        if (_shareRate != 0) interestFields.shareRate = _shareRate;
        if (_nextAddInterestTimestamp != 0)
            interestFields.nextAddInterestTimestamp = _nextAddInterestTimestamp;
    }

    /** Set Stat Fields
        @param _totalStaked {uint128}
        @param _totalShares {uint128}
        @param _totalVCA {uint128}
        @param _lastId {uint128}
     */
    function setStatFields(
        uint72 _totalStaked,
        uint72 _totalShares,
        uint72 _totalVCA,
        uint40 _lastId
    ) external onlyMigrator {
        if (_totalStaked != 0) statFields.totalStakedAmount = _totalStaked;
        if (_totalShares != 0) statFields.sharesTotalSupply = _totalShares;
        if (_totalVCA != 0) statFields.totalVcaRegisteredShares = _totalVCA;
        if (_lastId != 0) statFields.lastStakeId = _lastId;
    }

    /** Set Settings Fields
        @param _shareRateScalingFactor {uint128}
        @param _secondsInDay {uint128}
        @param _contractStartTimestamp {uint128}
        @param _bpdDayRange {uint128}
     */
    function setSettings(
        uint128 _shareRateScalingFactor,
        uint32 _secondsInDay,
        uint64 _contractStartTimestamp,
        uint32 _bpdDayRange
    ) external onlyMigrator {
        if (_shareRateScalingFactor != 0) settings.shareRateScalingFactor = _shareRateScalingFactor;
        if (_secondsInDay != 0) settings.secondsInDay = _secondsInDay;
        if (_contractStartTimestamp != 0) settings.contractStartTimestamp = _contractStartTimestamp;
        if (_bpdDayRange != 0) settings.bpdDayRange = _bpdDayRange;
    }

    /* Basic Getters ------------------------------------------------------------------------------------------------*/

    /** Get Stake
        @param id {uint256}

        @return {StakeData}
     */
    function getStake(uint256 id) external view override returns (StakeData memory) {
        return stakeData[id];
    }

    /** Get Stake
        @param id {uint256}

        @return {uint256} - End date in seconds of stake
     */
    function getStakeEnd(uint256 id) external view override returns (uint256) {
        return stakeData[id].start + (settings.secondsInDay * stakeData[id].stakingDays);
    }

    function getStakeShares(uint256 id) external view override returns (uint256) {
        return stakeData[id].shares;
    }

    /** Get Stake Withdrawn
        @param id {uint256}

        @return {bool} - Stake withdrawn
     */
    function getStakeWithdrawn(uint256 id) external view override returns (bool) {
        return stakeData[id].status == StakeStatus.Withdrawn;
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

    /** get Total VCA Registered Shares
        Description: This function will return the total registered shares for VCA
        This differs from the total share supply due to the fact of V1 and V2 layer

        @return {uint256} - Total Registered Shares for VCA
     */
    function getTotalVcaRegisteredShares() external view override returns (uint256) {
        return statFields.totalVcaRegisteredShares * 1e12;
    }

    function getStatFields() external view returns (StatFields memory) {
        return statFields;
    }

    function getInterestFields() external view returns (InterestFields memory) {
        return interestFields;
    }

    function getSettings() external view returns (Settings memory) {
        return settings;
    }

    function findBpdEligible(uint256 start, uint256 end) external view returns (uint16[2] memory) {
        return getBpdInterval(start, end);
    }

    function getBpd() external view returns (BpdPool memory) {
        return bpd;
    }

    function getDaysFromStart() external view returns (uint256) {
        return (block.timestamp - settings.contractStartTimestamp) / settings.secondsInDay;
    }
}