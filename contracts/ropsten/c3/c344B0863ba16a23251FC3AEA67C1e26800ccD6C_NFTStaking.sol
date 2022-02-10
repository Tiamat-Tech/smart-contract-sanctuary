//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


contract NFTStaking is Context, ERC1155Holder, Ownable {
    using SafeMath for uint256;

    struct STAKE {
        uint256 amount;
        uint256 rewardSoFar;
        uint256 firstStakedAt;
        uint256 lastClaimedAt;
    }

    struct POOL {
        uint256 poolId;
        IERC1155 nftToken;
        uint256 nftTokenId;
        IERC20 rewardToken;
        uint256 totalStakes;
        uint256 totalRewards;
        uint256 rewardPerNFT;
    }

    /// @dev map poolId to staking Pool detail
    uint public stakingPoolsCount;
    mapping(uint256 => POOL) stakingPools;
    mapping(uint256 => mapping(address => STAKE)) balances;

    event Stake(uint256 indexed poolId, address staker, uint256 amount);
    event Unstake(uint256 indexed poolId, address staker, uint256 amount);
    event Withdraw(uint256 indexed poolId, address staker, uint256 amount);

    constructor() {
        stakingPoolsCount = 0;
    }

    /**
     * @notice get all existing staking pool id's
     * @return stakingPools
     */
    function getStakingPools() public view returns (uint[] memory) {
      uint[] memory pools = new uint[](stakingPoolsCount);
      for (uint i = 0; i < stakingPoolsCount; i++) {
          pools[i] = stakingPools[i].poolId;
      }
      return pools;
    }

    /**
     * @notice get pool rewards by specific token 
     * @param token is the address to look for rewards with
     * @return sum of all remaining rewards in specific token among all pools
     */
    function getPoolRewards(address token) public view returns (uint256) {
        uint total = 0;
        for (uint i = 0; i < stakingPoolsCount; i++) {
            POOL memory pool = stakingPools[i];
            address poolRewardToken = address(pool.rewardToken);
            if (token == poolRewardToken) {
                uint poolRewards = pool.totalRewards;
                total = total + poolRewards;
                assert(total >= poolRewards);
            }
        }
        return total;
    }

    /**
     * @notice get staking pool by id
     * @param poolId is the staking pool identifier
     * @return stakingPool
     */
    function getStakingPool(uint256 poolId) public view returns (POOL memory) {
      return stakingPools[poolId];
    }

    /**
     * @notice calculate total stakes of staker
     * @param _staker is the address of staker
     * @return _total
     */
    function totalStakeOf(uint256 poolId, address _staker) public view returns (uint256) {
        return balances[poolId][_staker].amount;
    }

    /**
     * @notice calculate entire stake amount
     * @return _total
     */
    function getTotalStakes(uint256 poolId) public view returns (uint256) {
        return stakingPools[poolId].totalStakes;
    }

    /**
     * @notice get the first staked time
     * @return firstStakedAt
     */
    function getFirstStakedAtOf(uint256 poolId, address _staker) public view returns (uint256) {
        return balances[poolId][_staker].firstStakedAt;
    }

    /**
     * @notice get total claimed reward of staker
     * @return rewardSoFar
     */
    function getRewardSoFarOf(uint256 poolId, address _staker) public view returns (uint256) {
        return balances[poolId][_staker].rewardSoFar;
    }

    /**
     * @notice calculate reward of staker
     * @return reward is the reward amount of the staker
     */
    function rewardOf(uint256 poolId, address _staker) public view returns (uint256) {
        POOL memory poolInfo = stakingPools[poolId];
        STAKE memory stakeDetail = balances[poolId][_staker];

        if (stakeDetail.amount == 0) return 0;

        uint256 timePassed;
        uint256 timeNow = block.timestamp;

        timePassed = timeNow - stakeDetail.lastClaimedAt;

        uint256 _totalReward = stakeDetail.amount.mul(poolInfo.rewardPerNFT).mul(timePassed).div(30 days);

        if (_totalReward > poolInfo.totalRewards) return poolInfo.totalRewards;
        return _totalReward;
    }

    function claimReward(uint256 poolId) public {
        uint256 reward = rewardOf(poolId, _msgSender());

        POOL memory poolInfo = stakingPools[poolId];
        STAKE storage _stake = balances[poolId][_msgSender()];

        poolInfo.rewardToken.transfer(_msgSender(), reward);
        _stake.lastClaimedAt = block.timestamp;
        _stake.rewardSoFar = _stake.rewardSoFar.add(reward);
        poolInfo.totalRewards = poolInfo.totalRewards.sub(reward);

        emit Withdraw(poolId, _msgSender(), reward);
    }

    /**
     * @notice stake KEX
     * @param _amount is the kex amount to stake
     */
    function stake(uint256 poolId, uint256 _amount) external {
        POOL memory poolInfo = stakingPools[poolId];

        poolInfo.nftToken.safeTransferFrom(_msgSender(), address(this), poolInfo.nftTokenId, _amount, '');

        STAKE storage _stake = balances[poolId][_msgSender()];

        if (_stake.amount > 0) {
            uint256 reward = rewardOf(poolId, _msgSender());

            poolInfo.rewardToken.transfer(_msgSender(), reward);
            _stake.rewardSoFar = _stake.rewardSoFar.add(reward);
            poolInfo.totalRewards = poolInfo.totalRewards.sub(reward);

            emit Withdraw(poolId, _msgSender(), reward);
        }
        if (_stake.amount == 0) _stake.firstStakedAt = block.timestamp;

        _stake.lastClaimedAt = block.timestamp;
        _stake.amount = _stake.amount.add(_amount);
        stakingPools[poolId].totalStakes = stakingPools[poolId].totalStakes.add(_amount);

        emit Stake(poolId, _msgSender(), _amount);
    }

    /**
     * @notice unstake current staking
     */
    function unstake(uint256 poolId, uint256 count) external {
        require(balances[poolId][_msgSender()].amount > 0, 'Not staking');

        POOL memory poolInfo = stakingPools[poolId];
        STAKE storage _stake = balances[poolId][_msgSender()];
        uint256 reward = rewardOf(poolId, _msgSender()).div(_stake.amount).mul(count);

        poolInfo.rewardToken.transfer(_msgSender(), reward);
        poolInfo.nftToken.safeTransferFrom(address(this), _msgSender(), poolInfo.nftTokenId, count, '');

        poolInfo.totalStakes = poolInfo.totalStakes.sub(count);
        poolInfo.totalRewards = poolInfo.totalRewards.sub(reward);

        _stake.amount = _stake.amount.sub(count);
        _stake.rewardSoFar = _stake.rewardSoFar.add(reward);

        if (_stake.amount == 0) {
            _stake.firstStakedAt = 0;
            _stake.lastClaimedAt = 0;
        }

        emit Unstake(poolId, _msgSender(), count);
    }

    

    /**
     * @notice function to notify contract how many rewards to assign for the pool
     * @param poolId is the pool id to contribute reward
     * @param amount is the amount to put
     */
    function notifyRewards(uint256 poolId, uint256 amount) public onlyOwner {
        require(amount > 0, "NFTStaking.notifyRewards: Can't add zero amount!");

        POOL storage poolInfo = stakingPools[poolId];
        uint total = poolInfo.rewardToken.balanceOf(address(this));
        uint reserved = getPoolRewards(address(poolInfo.rewardToken));

        require(total.sub(reserved) >= amount, "NFTStaking.notifyRewards: Can't add more tokens than available");
        poolInfo.totalRewards = poolInfo.totalRewards.add(amount);
    }

    /**
     * @notice function to put staking rewards in the contract
     * @param poolId is the pool id to contribute reward
     * @param amount is the amount to put
     */
    function withdrawRewards(uint256 poolId, uint256 amount) public onlyOwner {
        require(stakingPools[poolId].totalRewards >= amount, 'NFTStaking.withdrawRewards: Not enough remaining rewards!');
        POOL storage poolInfo = stakingPools[poolId];
        poolInfo.rewardToken.transfer(_msgSender(), amount);
        poolInfo.totalRewards = poolInfo.totalRewards.sub(amount);
    }

    function addPool(
        uint256 poolId,
        IERC1155 nftToken,
        uint256 nftTokenId,
        IERC20 rewardToken,
        uint256 rewardPerNFT
    ) public onlyOwner {
        require(stakingPools[poolId].rewardPerNFT == 0, 'NFTStaking.addPool: Pool already exists!');
        require(stakingPools[poolId].poolId == 0, 'NFTStaking.addPool: poolId already exists!');

        stakingPools[poolId] = POOL(poolId, nftToken, nftTokenId, rewardToken, 0, 0, rewardPerNFT);
        stakingPoolsCount++;
    }
}