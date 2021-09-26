// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingPool is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using Counters for Counters.Counter;

    struct Asset {
        uint256 stakeId;
        uint256 sksAmount;
        uint256 vesksAmount;
        uint256 startTime;
        uint256 finishTime;
    }

    struct Staker {
        uint256 power;
        int256 rewardDebt;
        Asset[] stakedAssets;
    }

    struct Reward
    {
        uint256 rewardBalance;
        uint256 expiredBlock;
        uint256 startBlock;
        uint256 totalBalance;
        uint256 accRewardPerPower;
        uint256 lastRewardBlock;
    }

    bytes32 public constant REWARD_ROLE = keccak256("REWARD_ROLE");
    uint256 private constant ACC_REWARD_PRECISION = 1e8;
    mapping(uint256 => uint256[2]) private durations;

    Counters.Counter private _stakeIdCounter;
    IERC20 private stakingToken;

    mapping(address=>Staker) public users;
    mapping(uint8=>uint256) public powerAlloc;
    mapping(address=>Reward) public rewards;
    address[] public rewardList;
    uint256 public totalPower;

    uint256 public totalStaked;

    event Deposit(address indexed account, uint256 indexed stakeId, uint256 sksAmount, uint256 vesksAmount, uint256 duration);
    event Withdraw(address indexed account, uint256 indexed stakeId, uint256 sksAmount, uint256 vesksAmount);
    event Havest(address indexed account, address indexed token, uint256 amount);

    constructor(
        IERC20 stakingToken_
    ) {
        stakingToken = stakingToken_;

        durations[0] = [60, 1]; // for test, fixme: 删除的时候要同步修改 deposit 的 require
        durations[1] = [604800, 208]; // one week
        durations[2] = [2592000, 48]; // one month
        durations[3] = [15552000, 8]; // half year
        durations[4] = [31536000, 4]; // one year
        durations[5] = [63072000, 2]; // two years
        durations[6] = [126144000, 1]; // four years

        _stakeIdCounter.increment();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(REWARD_ROLE, _msgSender());
    }

    function rewardPerBlock(address token) public view returns(uint256){
        Reward memory reward = rewards[token];
        if(reward.expiredBlock == reward.startBlock) {
            return 0;
        }
        return reward.rewardBalance.div(reward.expiredBlock.sub(reward.startBlock));
    }

    function _updateReward(address token) internal {
        Reward memory reward = rewards[token];
        uint256 startBlock = Math.max(reward.lastRewardBlock, reward.startBlock);
        uint256 endBlock = Math.min(reward.expiredBlock, block.number);

        if(endBlock > startBlock) {
            if(totalPower > 0) {
                uint256 blocks = endBlock.sub(startBlock);
                uint256 profit = blocks.mul(rewardPerBlock(token));
                reward.accRewardPerPower = reward.accRewardPerPower.add(profit.mul(ACC_REWARD_PRECISION) / totalPower);
            }
            reward.lastRewardBlock = endBlock;
            rewards[token] = reward;
        }
    }

    function _updateRewards() internal {
        for(uint i = 0; i < rewardList.length; i++) {
            _updateReward(rewardList[i]);
        }
    }

    function _updateUserDebt(address user, uint256 power, bool addOrSub) internal {
        for(uint i = 0; i < rewardList.length; i++) {
            if(addOrSub) {
                users[user].rewardDebt = users[user].rewardDebt.add(
                    int256(power.mul(rewards[rewardList[i]].accRewardPerPower) / ACC_REWARD_PRECISION)
                );
            } else {
                users[user].rewardDebt = users[user].rewardDebt.sub(
                    int256(power.mul(rewards[rewardList[i]].accRewardPerPower) / ACC_REWARD_PRECISION)
                );
            }
        }
    }

    function pendingReward(address token, address _user) external view returns (uint256 pending) {
        Reward memory reward = rewards[token];
        Staker memory user   = users[_user];
        
        uint256 accRewardPerPower = reward.accRewardPerPower;
        uint256 startBlock = Math.max(reward.lastRewardBlock, reward.startBlock);
		uint256 endBlock = Math.min(reward.expiredBlock, block.number);

        if (endBlock > startBlock && totalPower != 0) {
			uint256 blocks = endBlock.sub(startBlock);
			uint256 tokenReward = blocks.mul(rewardPerBlock(token));
			accRewardPerPower = accRewardPerPower.add(tokenReward.mul(ACC_REWARD_PRECISION) / totalPower);
		}
		pending = uint256(int256(user.power.mul(accRewardPerPower) / ACC_REWARD_PRECISION).sub(user.rewardDebt));
    }

    function addReward(
        address token,
        uint256 amount,
        uint256 numBlocks
    )
        public
        onlyRole(REWARD_ROLE)
    {
        require(numBlocks > 0, "EBLOCK");
        require(amount > 0, "EAMOUNT");

        _updateReward(token);

        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);

        Reward memory reward = rewards[token];
        if(reward.expiredBlock == 0) {
            rewardList.push(token);
        }

        if(reward.expiredBlock > block.number) {
            reward.rewardBalance = reward.rewardBalance.mul(reward.expiredBlock.sub(block.number))
                .div(reward.expiredBlock.sub(reward.startBlock));
        }

        reward.rewardBalance = reward.rewardBalance.add(amount);
        reward.startBlock = block.number;
        reward.expiredBlock = block.number.add(numBlocks);
        reward.totalBalance = reward.totalBalance.add(amount);
        rewards[token] = reward;
    }

    function deposit(uint256 sksAmount, uint256 duration) external nonReentrant {
        require(sksAmount > 0, "EAMOUNT");
        require(duration >= 0 && duration <= 6, "EDURATION");

        stakingToken.safeTransferFrom(_msgSender(), address(this), sksAmount);

        uint256 vesksAmount = _sksToVesks(sksAmount, duration);
        Asset memory asset = Asset (
            _stakeIdCounter.current(),
            sksAmount,
            vesksAmount,
            block.timestamp,
            block.timestamp + durations[duration][0]
        );
        Staker storage staker = users[_msgSender()];
        staker.stakedAssets.push(asset);

        require(users[_msgSender()].power + vesksAmount >= users[_msgSender()].power, "EOVERFLOW");
        require(totalPower + vesksAmount >= totalPower, "EOVERFLOW");

        users[_msgSender()].power += vesksAmount;
        totalPower += vesksAmount;
        _updateUserDebt(_msgSender(), vesksAmount, true);

        totalStaked += sksAmount;

        _stakeIdCounter.increment();

        emit Deposit(_msgSender(), asset.stakeId, sksAmount, vesksAmount, duration);
    }

    function withdraw(uint256 stakeId) external nonReentrant {
        _updateRewards();

        Asset memory asset = _getAsset(_msgSender(), stakeId);

        require(block.timestamp >= asset.finishTime, "EUNFINISHED");
        require(users[_msgSender()].power - asset.vesksAmount <= users[_msgSender()].power, "EUNDERFLOW");
        require(totalPower - asset.vesksAmount <= totalPower, "EUNDERFLOW");

        _removeAsset(_msgSender(), stakeId);

        users[_msgSender()].power -= asset.vesksAmount;
        totalPower -= asset.vesksAmount;
        _updateUserDebt(_msgSender(), asset.vesksAmount, false);

        stakingToken.safeTransfer(_msgSender(), asset.sksAmount);

        totalStaked -= asset.sksAmount;

        emit Withdraw(_msgSender(), stakeId, asset.sksAmount, asset.vesksAmount);
    }

    function harvestAll(address to) public {
        for(uint i = 0; i < rewardList.length; i++) {
            address token = rewardList[i];

            _updateReward(token);

            Reward memory reward = rewards[token];
            Staker storage user   = users[msg.sender];

            int256 accReward = int256(user.power.mul(reward.accRewardPerPower) / ACC_REWARD_PRECISION);
            uint256 _pendingReward = uint256(accReward.sub(user.rewardDebt));
            user.rewardDebt = accReward;

            if(_pendingReward > 0) {
                IERC20(token).transfer(to, _pendingReward);
            }

            emit Havest(_msgSender(), token, _pendingReward);
        }
    }

    function _removeAsset(address user, uint256 stakeId) internal {
        for(uint i = 0; i < users[user].stakedAssets.length; i++) {
            if(stakeId == users[user].stakedAssets[i].stakeId)
            {
                users[user].stakedAssets[i] = users[user].stakedAssets[users[user].stakedAssets.length - 1];
                users[user].stakedAssets.pop();
                return;
            }
        }
        require(false, "ENOTEXIST");
    }

    function _getAsset(
        address user, 
        uint256 stakeId
    )
        internal 
        view
        returns 
        (Asset memory asset)
    {
        for(uint i = 0; i < users[user].stakedAssets.length; i++) {
            if(stakeId == users[user].stakedAssets[i].stakeId) {
                return users[user].stakedAssets[i];
            }
        }
        require(false, "ENOTEXIST");
    }

    function _sksToVesks(uint256 sksAmount, uint256 duration) internal view returns(uint256) {
        return sksAmount / durations[duration][1];
    }
}