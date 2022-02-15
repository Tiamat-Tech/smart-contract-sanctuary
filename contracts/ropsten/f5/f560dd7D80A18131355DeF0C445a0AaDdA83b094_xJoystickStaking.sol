// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/Authorizable.sol";
import "./tokens/JoyToken.sol";
import "./tokens/xJoyToken.sol";
import "./JoystickPresale.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once JOY is sufficiently
// distributed and the community can show to govern itself.
//
contract xJoystickStaking is Authorizable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for JoyToken;
    using SafeERC20 for xJoyToken;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardDebtAtTimestamp; // the last block user stake
        uint256 lastWithdrawTimestamp; // the last block a user withdrew at.
        uint256 firstDepositTimestamp; // the last block a user deposited at.
        uint256 lastDepositTimestamp;
        //
        // We do some fancy math here. Basically, at any point in time, the
        // amount of xJOY
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * accGovTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to this staker. Here's what happens:
        //   1. The `accGovTokenPerShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    JoystickPresale[] presaleList;
    JoyToken govToken; // Address of Gov token contract. JOY token
    xJoyToken lpToken; // Address of LP token contract. xJOY token
    uint256 lastRewardTimestamp; // Last block number that JOY distribution occurs.
    uint256 accGovTokenPerShare; // Accumulated JOY per share, times 1e12. See below.
    mapping(address => uint256) _locks;
    mapping(address => uint256) _lastUnlockTimestamp;
    uint256 _totalLock;
    uint256 lockFromTimestamp;
    uint256 lockToTimestamp;

    // JOY created per block.
    uint256 public REWARD_PER_EPOCH;
    // Bonus multiplier for early JOY makers.
    uint256[] public REWARD_MULTIPLIER; // init in constructor function
    uint256 public FINISH_BONUS_AT_TIMESTAMP;
    uint256 public userDepFee;
    uint256 public EPOCH_LENGTH; // init in constructor function
    uint256[] public EPOCH_LIST; // init in constructor function
    uint256[] public POOL_START; // init in constructor function
    uint256 public POOL_EPOCH_COUNT; // init in constructor function

    // The day when JOY mining starts.
    uint256[] public START_TIMESTAMP;

    uint256[] public PERCENT_LOCK_BONUS_REWARD; // lock xx% of bounus reward

    // Info of each user that stakes LP tokens. pid => user address => info
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount
    );
    event SendGovernanceTokenReward(
        address indexed user,
        uint256 amount,
        uint256 lockAmount
    );
    event Lock(address indexed to, uint256 value);
    event Unlock(address indexed to, uint256 value);

    constructor(
        JoyToken _govToken,
        xJoyToken _lpToken,
        uint256 _rewardPerEpoch,
        uint256 _userDepFee
    ) {
        govToken = _govToken;
        lpToken = _lpToken;
        REWARD_PER_EPOCH = _rewardPerEpoch;

        EPOCH_LENGTH = 7 days;
        userDepFee = _userDepFee;

        accGovTokenPerShare = 0;
        _totalLock = 0;
        lockFromTimestamp = 0;
        lockToTimestamp = 0;
    }

    // Update presale list
    function presaleUpdate(address[] memory _presaleList) public onlyAuthorized {
        delete presaleList;
        for (uint i=0; i<_presaleList.length; i++) {
            presaleList.push(JoystickPresale(_presaleList[i]));
        }
    }

    // Update lpToken address
    function lpTokenUpdate(address _lpToken) public onlyAuthorized {
        lpToken = xJoyToken(_lpToken);
    }

    // Update govToken address
    function govTokenUpdate(address _govToken) public onlyAuthorized {
        govToken = JoyToken(_govToken);
    }

    // Get all LP Supply from the all purchased users balance
    function getLpSupply() public view returns ( uint256 ) {
        uint256 totalSoldAmount = 0;
        for (uint256 i=0; i<presaleList.length; i++) {
            totalSoldAmount += presaleList[i].totalSoldAmount();
        }
        return totalSoldAmount;
    }

    // Update reward variables to be up-to-date.
    function updateRewardInfo() internal {
        if (block.timestamp <= lastRewardTimestamp || block.timestamp <= START_TIMESTAMP[0]) {
            return;
        }
        uint256 lpSupply = getLpSupply();
        if (lastRewardTimestamp == 0) {
            lastRewardTimestamp = START_TIMESTAMP[0];
        }
        uint256 GovTokenForFarmer = getReward(lastRewardTimestamp, block.timestamp);
        // Mint some new JOY tokens for the farmer and store them in JoystickStaking.
        // govToken.mint(address(this), GovTokenForFarmer);
        accGovTokenPerShare = accGovTokenPerShare.add(
            GovTokenForFarmer.mul(1e12).div(lpSupply)
        );
        lastRewardTimestamp = block.timestamp;
    }

    // |--------------------------------------|
    // Return reward multiplier over the given _from to _to timestamp.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 result = 0;
        if (_from < START_TIMESTAMP[0]) return 0;

        uint index = 0;
        for (uint256 j = 0; j < POOL_START.length; j++) {
            for (uint256 i = 0; i < EPOCH_LIST.length; i++) {
                uint256 endEpoch = EPOCH_LIST[i].add(START_TIMESTAMP[j]);
                if (j == POOL_START.length - 1) endEpoch = type(uint128).max;
                if (index > REWARD_MULTIPLIER.length-1) return 0;

                if (_to <= endEpoch) {
                    uint256 m = _to.sub(_from).mul(1e12).div(EPOCH_LENGTH).mul(REWARD_MULTIPLIER[index]);
                    return result.add(m);
                }

                if (_from < endEpoch) {
                    uint256 m = endEpoch.sub(_from).mul(1e12).div(EPOCH_LENGTH).mul(REWARD_MULTIPLIER[index]);  // convert by epoch unit, and multiply
                    _from = endEpoch;
                    result = result.add(m);
                }
                index++;
            }
        }

        return result;
    }

    function getLockPercentage(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 result = 0;
        if (_from < START_TIMESTAMP[0]) return 100;

        uint256 index = 0;
        for (uint256 j = 0; j < POOL_START.length; j++) {
            for (uint256 i = 0; i < EPOCH_LIST.length; i++) {
                uint256 endTimestamp = EPOCH_LIST[i].add(START_TIMESTAMP[j]);
                if (j == POOL_START.length) endTimestamp = type(uint128).max;
                if (index > PERCENT_LOCK_BONUS_REWARD.length-1) return 0;

                if (_to <= endTimestamp) {
                    return PERCENT_LOCK_BONUS_REWARD[index];
                }
                index++;
            }
        }

        return result;
    }

    function getReward(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 multiplier = getMultiplier(_from, _to);
        uint256 amount = multiplier.mul(REWARD_PER_EPOCH).div(1e12);

        return amount;
    }

    // View function to see pending JOY on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 accGovTokenPerShare_ = accGovTokenPerShare;
        uint256 userBalance = lpToken.balanceOf(_user);
        uint256 lpSupply = getLpSupply();
        uint256 _lastRewardTimestamp = lastRewardTimestamp;
        
        if (block.timestamp <= START_TIMESTAMP[0]) {
            return 0;
        }

        if (_lastRewardTimestamp == 0) {
            _lastRewardTimestamp = START_TIMESTAMP[0];
        }
        if (block.timestamp > _lastRewardTimestamp && lpSupply > 0) {
            uint256 GovTokenForFarmer = getReward(_lastRewardTimestamp, block.timestamp);
            accGovTokenPerShare_ = accGovTokenPerShare_.add(
                GovTokenForFarmer.mul(1e12).div(lpSupply)
            );
        }

        return userBalance.mul(accGovTokenPerShare_).div(1e12).sub(user.rewardDebt);
    }

    function claimReward() public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 userBalance = lpToken.balanceOf(msg.sender);
        if (userBalance > user.amount) {
            _deposit(msg.sender, userBalance.sub(user.amount));
            return;
        }

        updateRewardInfo();
        _harvest(msg.sender);
    }

    // lock a % of reward if it comes from bonus time.
    function _harvest(address holder) internal {
        UserInfo storage user = userInfo[holder];

        // Only harvest if the user amount is greater than 0.
        if (user.amount > 0) {
            // Calculate the pending reward. This is the user's amount of LP
            // tokens multiplied by the accGovTokenPerShare, minus
            // the user's rewardDebt.
            uint256 pending =
                user.amount.mul(accGovTokenPerShare).div(1e12).sub(
                    user.rewardDebt
                );

            // Make sure we aren't giving more tokens than we have in the
            // JDaoStaking contract.
            uint256 masterBal = govToken.balanceOf(address(this));

            if (pending > masterBal) {
                pending = masterBal;
            }

            if (pending > 0) {
                // If the user has a positive pending balance of tokens, transfer
                // those tokens from JDaoStaking to their wallet.
                uint256 lockAmount = 0;
                if (user.rewardDebtAtTimestamp <= FINISH_BONUS_AT_TIMESTAMP) {
                    // If we are before the FINISH_BONUS_AT_TIMESTAMP moment, we need
                    // to lock some of those tokens, based on the current lock
                    // percentage of their tokens they just received.
                    uint256 lockPercentage = getLockPercentage(block.timestamp - 60, block.timestamp);
                    lockAmount = pending.mul(lockPercentage).div(100);
                    lock(holder, lockAmount);
                    govToken.transfer(holder, pending.sub(lockAmount));
                } else {
                    govToken.transfer(holder, pending);
                }

                // Reset the rewardDebtAtTimestamp to the current timestamp for the user.
                user.rewardDebtAtTimestamp = block.timestamp;

                emit SendGovernanceTokenReward(holder, pending, lockAmount);
            }

            // Recalculate the rewardDebt for the user.
            user.rewardDebt = user.amount.mul(accGovTokenPerShare).div(1e12);
        }
    }

    // Deposit LP tokens to JDaoStaking for JOY allocation.
    function _deposit(address holder, uint256 _amount) public nonReentrant {
        require(
            _amount > 0,
            "xJoyStaking::deposit: amount must be greater than 0"
        );

        UserInfo storage user = userInfo[holder];

        // When a user deposits, we need to update the staker and harvest beforehand,
        // since the rates will change.
        updateRewardInfo();
        _harvest(holder);
        if (user.amount == 0) {
            user.rewardDebtAtTimestamp = block.timestamp;
        }
        user.amount = user.amount.add(
            _amount.sub(_amount.mul(userDepFee).div(10000))
        );
        user.rewardDebt = user.amount.mul(accGovTokenPerShare).div(1e12);
        emit Deposit(holder, _amount);
        if (user.firstDepositTimestamp > 0) {} else {
            user.firstDepositTimestamp = block.timestamp;
        }
        user.lastDepositTimestamp = block.timestamp;
    }

    function deposit(uint256 _amount) public nonReentrant {
        _deposit(msg.sender, _amount);
    }

    // Safe GovToken transfer function, just in case if rounding error causes this staker to not have enough GovTokens.
    function safeGovTokenTransfer(address _to, uint256 _amount) internal {
        uint256 govTokenBal = govToken.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > govTokenBal) {
            transferSuccess = govToken.transfer(_to, govTokenBal);
        } else {
            transferSuccess = govToken.transfer(_to, _amount);
        }
        require(transferSuccess, "xJoyStaking::safeGovTokenTransfer: transfer failed");
    }

    // Update Finish Bonus Timestamp
    function bonusFinishUpdate(uint256 _newFinish) public onlyAuthorized {
        FINISH_BONUS_AT_TIMESTAMP = _newFinish;
        lockToUpdate(FINISH_BONUS_AT_TIMESTAMP);
    }

    // Update Halving At Block
    function epochListUpdate(uint256[] memory _newEpochList) public onlyAuthorized {
        EPOCH_LIST = _newEpochList;
    }

    // Update Epoch count per pool
    function poolEpochCountUpdate(uint256 _newPoolEpochCount) public onlyAuthorized {
        POOL_EPOCH_COUNT = _newPoolEpochCount;
        delete EPOCH_LIST;
        initEpochList();
    }

    // Update pool start list
    function poolStartUpdate(uint256[] memory _newPoolStart) public onlyAuthorized {
        POOL_START = _newPoolStart;
    }

    // Update Rewards Mulitplier Array
    function rewardMulUpdate(uint256[] memory _newMulReward) public onlyAuthorized {
        REWARD_MULTIPLIER = _newMulReward;
    }

    // Update % lock for general users
    function lockUpdate(uint256[] memory _newlock) public onlyAuthorized {
        PERCENT_LOCK_BONUS_REWARD = _newlock;
    }

    // Update EPOCH_LENGTH
    function epochLengthUpdate(uint256 _newEpochLength) public onlyAuthorized {
        EPOCH_LENGTH = _newEpochLength;
        delete EPOCH_LIST;
        initEpochList();
    }

    // Initialize the start timestamp list based on _newStartTimestamp
    function initStartTimestamp(uint256 _newStartTimestamp) internal {
        for (uint i = 0; i < POOL_START.length; i++) {
            START_TIMESTAMP.push(EPOCH_LENGTH.mul(POOL_START[i]).add(_newStartTimestamp));
        }
    }

    // Initialize the Epoch List
    function initEpochList() internal {
        for (uint256 i = 0; i < POOL_EPOCH_COUNT; i++) {
            EPOCH_LIST.push(EPOCH_LENGTH.mul(i+1).add(1));
        }
    }

    // Update START_TIMESTAMP
    function startTimestampUpdate(uint256 _newStartTimestamp) public onlyAuthorized {
        delete START_TIMESTAMP;
        initStartTimestamp(_newStartTimestamp);
    }

    function getNewRewardPerEpoch() public view returns (uint256) {
        uint256 multiplier = getMultiplier(block.timestamp - 60, block.timestamp);
        return multiplier.mul(REWARD_PER_EPOCH).div(1e12);
    }

    function getNewRewardPerMinute() public view returns (uint256) {
        return getNewRewardPerEpoch().div(EPOCH_LENGTH).mul(60);
    }

    function reviseDeposit(address _user, uint256 _timestamp) public onlyAuthorized() {
        UserInfo storage user = userInfo[_user];
        user.firstDepositTimestamp = _timestamp;
    }

    function reclaimTokenOwnership(address _newOwner) public onlyAuthorized() {
        govToken.transferOwnership(_newOwner);
    }

    // Update the lockFromTimestamp
    function lockFromUpdate(uint256 _newLockFrom) public onlyAuthorized {
        lockFromTimestamp = _newLockFrom;
    }

    // Update the lockToTimestamp
    function lockToUpdate(uint256 _newLockTo) public onlyAuthorized {
        lockToTimestamp = _newLockTo;
    }

    function unlockedSupply() public view returns (uint256) {
        return govToken.totalSupply().sub(_totalLock);
    }

    function lockedSupply() public view returns (uint256) {
        return totalLock();
    }

    function circulatingSupply() public view returns (uint256) {
        return govToken.totalSupply();
    }

    function totalLock() public view returns (uint256) {
        return _totalLock;
    }

    function lockOf(address _holder) public view returns (uint256) {
        return _locks[_holder];
    }

    function lastUnlockTimestamp(address _holder) public view returns (uint256) {
        return _lastUnlockTimestamp[_holder];
    }

    function lock(address _holder, uint256 _amount) internal {
        require(_holder != address(0), "Cannot lock to the zero address");
        require(
            _amount <= govToken.balanceOf(_holder),
            "Lock amount over balance"
        );

        _locks[_holder] = _locks[_holder].add(_amount);
        _totalLock = _totalLock.add(_amount);
        if (_lastUnlockTimestamp[_holder] < lockFromTimestamp) {
            _lastUnlockTimestamp[_holder] = lockFromTimestamp;
        }
        emit Lock(_holder, _amount);
    }

    function canUnlockAmount(address _holder) public view returns (uint256) {
        if (block.timestamp < lockFromTimestamp) {
            return 0;
        } else if (block.timestamp >= lockToTimestamp) {
            return _locks[_holder];
        } else {
            uint256 releaseTime = block.timestamp.sub(_lastUnlockTimestamp[_holder]);
            uint256 numberLockTime =
                lockToTimestamp.sub(_lastUnlockTimestamp[_holder]);
            return _locks[_holder].mul(releaseTime).div(numberLockTime);
        }
    }

    // Unlocks some locked tokens immediately.
    function unlockForUser(address account, uint256 amount) public onlyAuthorized {
        // First we need to unlock all tokens the address is eligible for.
        uint256 pendingLocked = canUnlockAmount(account);
        if (pendingLocked > 0) {
            _unlock(account, pendingLocked);
        }

        // Now that that's done, we can unlock the extra amount passed in.
        _unlock(account, amount);
    }

    function unlock() public {
        uint256 amount = canUnlockAmount(msg.sender);
        _unlock(msg.sender, amount);
    }

    function _unlock(address holder, uint256 amount) internal {
        require(_locks[holder] > 0, "Insufficient locked tokens");

        // Make sure they aren't trying to unlock more than they have locked.
        if (amount > _locks[holder]) {
            amount = _locks[holder];
        }

        // If the amount is greater than the total balance, set it to max.
        if (amount > govToken.balanceOf(address(this))) {
            amount = govToken.balanceOf(address(this));
        }
        _locks[holder] = _locks[holder].sub(amount);
        _lastUnlockTimestamp[holder] = block.timestamp;
        _totalLock = _totalLock.sub(amount);

        emit Unlock(holder, amount);
    }
}