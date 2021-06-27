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
        statFields.lastStakeId++; // 7k

        uint256 shares = getStakersSharesAmountInternal(amount, stakingDays); // 1k gas

        addToGlobalTotals(amount, shares); // 10k
        createStakeInternal( // 35k
            NewStake({
                id: statFields.lastStakeId,
                amount: amount,
                shares: shares,
                start: block.timestamp,
                stakingDays: stakingDays
            })
        );

        contracts.vcAuction.addTotalSharesOfAndRebalance(staker, shares); // 15k after first stake

        if (stakingDays >= settings.bpdDayRange) {
            // 30k
            contracts.bpd.addBpdShares(shares, block.timestamp, stakingDays);
        }

        emit StakeCreated( // 5k
            staker,
            statFields.lastStakeId,
            stakeData[statFields.lastStakeId].amount,
            stakeData[statFields.lastStakeId].shares,
            stakeData[statFields.lastStakeId].start,
            stakeData[statFields.lastStakeId].stakingDays
        );

        return statFields.lastStakeId;
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
    ) external override onlyExternalCaller returns (StakeData memory) {
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

        return stakeData[id];
    }

    /** Upgrade Existing Stake
        Description: Upgrade existing stake layer 3 with max shares (5555 day stake)
        @param id {uint256} - ID should be less then LastSessionIdV3

        Modifier: OnlyExternalCaller - Can only be called by StakeUpgrader
     */
    function upgradeExistingStake(uint256 id, address staker) external override onlyExternalCaller {
        upgradeStakeInternal(
            StakeUpgrade({
                id: id,
                staker: staker,
                firstInterestDay: stakeData[id].firstInterestDay,
                shares: uint256(stakeData[id].shares) * 1e12,
                amount: uint256(stakeData[id].amount) * 1e12,
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
        address staker,
        uint256 firstInterestDay,
        uint256 shares,
        uint256 amount,
        uint256 start,
        uint256 stakingDays
    ) external override onlyExternalCaller {
        upgradeStakeInternal(
            StakeUpgrade({
                id: id,
                staker: staker,
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
    function upgradeStakeInternal(StakeUpgrade memory stakeUpgrade) internal {
        uint256 newAmount = getStakeInterestInternal(
            stakeUpgrade.firstInterestDay,
            stakeUpgrade.stakingDays,
            stakeUpgrade.shares
        ) + stakeUpgrade.amount;

        uint256 intendedEnd = stakeUpgrade.start +
            (settings.secondsInDay * stakeUpgrade.stakingDays);

        // We use "Actual end" so that if a user tries to withdraw their BPD early they don't get the shares
        if (stakeUpgrade.stakingDays >= settings.bpdDayRange) {
            newAmount += contracts.bpd.getBpdAmount(
                stakeUpgrade.shares,
                stakeUpgrade.start,
                block.timestamp < intendedEnd ? block.timestamp : intendedEnd
            );
        }

        uint256 newShares = getStakersSharesAmountInternal(newAmount, 5555);

        require(
            newShares > stakeUpgrade.shares,
            'STAKING: New shares are not greater then previous shares'
        );

        uint256 newEnd = block.timestamp + (uint256(settings.secondsInDay) * 5555);

        contracts.vcAuction.addTotalSharesOfAndRebalance(stakeUpgrade.staker, newShares);
        contracts.bpd.addBpdMaxShares(
            stakeUpgrade.shares,
            stakeUpgrade.start,
            stakeUpgrade.start + (uint256(settings.secondsInDay) * stakeUpgrade.stakingDays),
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
    function getStakersSharesAmountInternal(uint256 amount, uint256 stakingDays)
        internal
        view
        returns (uint256)
    {
        uint256 numerator = amount * (1819 + stakingDays);
        uint256 denominator = 1820 * uint256(interestFields.shareRate);

        return (numerator * 1e18) / denominator;
    }

    function getStakersSharesAmount(uint256 amount, uint256 stakingDays)
        external
        view
        returns (uint256)
    {
        return getStakersSharesAmountInternal(amount, stakingDays);
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
    function unsetStake(
        address staker,
        uint256 id,
        uint256 payout
    ) external override onlyExternalCaller {
        unsetStakeInternal(
            staker,
            id,
            uint256(stakeData[id].shares) * 1e12,
            uint256(stakeData[id].amount) * 1e12,
            payout
        );

        // stake.amount = 0;
        // stake.shares = 0;
        // stake.start = 0;
        // stake.length = 0;
        // stake.firstInterestDay = 0;
        // might do this later
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
        uint256 stakingDays,
        uint256 payout
    ) external override onlyExternalCaller {
        stakeData[id].amount = (amount / 1e12).toUint64();
        stakeData[id].shares = (shares / 1e12).toUint64();
        stakeData[id].start = start.toUint40();
        stakeData[id].stakingDays = stakingDays.toUint16();
        stakeData[id].firstInterestDay = firstInterestDay.toUint24();
        // might remove this later

        unsetStakeInternal(staker, id, shares, amount, payout);
    }

    /** Delete Stake Internal (Common)
        Description: Unset stakes common functinality function
        @param staker {address}
        @param id {uint256}
        @param shares {uint256}
        @param amount {uint256}
        @param payout {uint256}

        Modifier: OnlyExternalCaller - Must be called by StakeBurner
     */
    function unsetStakeInternal(
        address staker,
        uint256 id,
        uint256 shares,
        uint256 amount,
        uint256 payout
    ) internal {
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

        stakeData[id].payout = (payout / 1e18).toUint40();
        stakeData[id].status = StakeStatus.Withdrawn;

        emit StakeDeleted(
            staker,
            id.toUint128(),
            stakeData[id].amount,
            stakeData[id].shares,
            stakeData[id].start,
            stakeData[id].stakingDays
        );
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
        uint256 lastInterest;
        uint256 firstInterest;
        uint256 lastInterestDay = firstInterestDay + stakingDays;

        if (interestPerShare.length != 0) {
            lastInterest = interestPerShare[
                MathUpgradeable.min(interestPerShare.length - 1, lastInterestDay - 1)
            ];
        }

        if (firstInterestDay != 0) {
            firstInterest = interestPerShare[firstInterestDay - 1];
        }

        return (shares * (lastInterest - firstInterest)) / 1e26;
    }

    function getStakeInterest(
        uint256 firstInterestDay,
        uint256 stakingDays,
        uint256 shares
    ) external view override returns (uint256) {
        return getStakeInterestInternal(firstInterestDay, stakingDays, shares);
    }

    function getStakeAndInterestById(uint256 stakeId)
        external
        view
        override
        returns (
            uint256 start,
            uint256 stakingDays,
            uint256 amount,
            uint256 shares,
            uint256 interest
        )
    {
        start = stakeData[stakeId].start;
        stakingDays = stakeData[stakeId].stakingDays;
        amount = uint256(stakeData[stakeId].amount) * 1e12;
        shares = uint256(stakeData[stakeId].shares) * 1e12;

        interest = getStakeInterestInternal(
            stakeData[stakeId].firstInterestDay,
            stakeData[stakeId].stakingDays,
            uint256(stakeData[stakeId].shares) * 1e12
        );
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

        if (statFields.sharesTotalSupply == 0) {
            statFields.sharesTotalSupply = 1e6;
        }

        if (interestPerShare.length != 0) {
            todaysSharePayout =
                interestPerShare[interestPerShare.length - 1] +
                ((interest * 1e26) / ((uint256(statFields.sharesTotalSupply) * 1e12)));
        } else {
            todaysSharePayout =
                (interest * 1e26) /
                ((uint256(statFields.sharesTotalSupply) * 1e12));
        }
        // 37,354.359062761739399567
        interestPerShare.push(todaysSharePayout);

        interestFields.nextAddInterestTimestamp += settings.secondsInDay;

        // call updateShareRate once a day as sharerate increases based on the daily Payout amount
        updateShareRate(interest);

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
        uint256 inflation = (8 *
            (currentTokenTotalSupply + (uint256(statFields.totalStakedAmount) * 1e12))) / 36500;

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

        uint256 growthFactor = (_payout * 1e18) /
            (currentTokenTotalSupply + (uint256(statFields.totalStakedAmount) * 1e12) + 1); //we calculate the total AXN supply as circulating + staked

        if (settings.shareRateScalingFactor == 0) {
            //use a shareRateScalingFactor which can be set in order to tune the speed of shareRate increase
            settings.shareRateScalingFactor = 1e18;
        }

        interestFields.shareRate = (
            ((uint256(interestFields.shareRate) *
                (1e36 + (uint256(settings.shareRateScalingFactor) * growthFactor))) / 1e36)
        )
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
        address _vcAuction,
        address _bpd
    ) public onlyMigrator {
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeMinter);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeBurner);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeUpgrader);
        _setupRole(EXTERNAL_CALLER_ROLE, _vcAuction);

        contracts.token = IToken(_token);
        contracts.vcAuction = IVCAuction(_vcAuction);
        contracts.bpd = IBpd(_bpd);
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

            if (sharesTotalSupply == 0) {
                sharesTotalSupply = 1e6;
            }

            if (interestPerShare.length != 0) {
                todaysSharePayout =
                    interestPerShare[interestPerShare.length - 1] +
                    ((interest * 1e26) / ((sharesTotalSupply * 1e12) + 1));
            } else {
                todaysSharePayout = (interest * 1e26) / ((sharesTotalSupply * 1e12) + 1);
            }

            interestPerShare.push(todaysSharePayout);
        }
    }

    /* Getters ------------------------------------------------------------------------------------------------*/

    /** Get Stake
        @param id {uint256}

        @return {StakeData}
     */
    function getStake(uint256 id) external view override returns (StakeData1e18 memory) {
        return
            StakeData1e18(
                uint256(stakeData[id].amount) * 1e12,
                uint256(stakeData[id].shares) * 1e12,
                stakeData[id].start,
                stakeData[id].stakingDays,
                stakeData[id].firstInterestDay,
                stakeData[id].payout,
                stakeData[id].status
            );
    }

    /** Get Stake
        @param id {uint256}

        @return {uint256} - End date in seconds of stake
     */
    function getStakeEnd(uint256 id) external view override returns (uint256) {
        return stakeData[id].start + (settings.secondsInDay * stakeData[id].stakingDays);
    }

    function getStakeShares(uint256 id) external view override returns (uint256) {
        return uint256(stakeData[id].shares) * 1e12;
    }

    /** Get Stake Withdrawn
        @param id {uint256}

        @return {bool} - Stake withdrawn
     */
    function getStakeWithdrawnOrExists(uint256 id) external view override returns (bool) {
        return
            stakeData[id].status == StakeStatus.Withdrawn ||
            stakeData[id].status != StakeStatus.Unknown;
    }

    /** get Total VCA Registered Shares
        Description: This function will return the total registered shares for VCA
        This differs from the total share supply due to the fact of V1 and V2 layer

        @return {uint256} - Total Registered Shares for VCA
     */
    function getTotalVcaRegisteredShares() external view override returns (uint256) {
        return uint256(statFields.totalVcaRegisteredShares) * 1e12;
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

    function getDaysFromStart() external view returns (uint256) {
        return (block.timestamp - settings.contractStartTimestamp) / settings.secondsInDay;
    }
}