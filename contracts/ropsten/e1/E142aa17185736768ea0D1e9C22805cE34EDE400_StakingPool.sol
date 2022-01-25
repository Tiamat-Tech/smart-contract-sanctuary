// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Upgradable.sol"; 

contract StakingPool is Upgradable {
    using SafeERC20 for IERC20;

    /*================================ MAIN FUNCTIONS ================================*/
    
    /**
     * @dev Stake token to a pool  
     * @param strs: poolId(0), internalTxID(1)
     * @param amount: amount of token user want to stake to the pool
    */
    function stakeToken(string[] memory strs, uint256 amount) external poolExist(strs[0]) notBlocked payable {
        string memory poolId = strs[0];
        PoolInfo storage pool = poolInfo[poolId];
        StakingData storage data = tokenStakingData[poolId][msg.sender];
        
        require(block.timestamp >= pool.configs[0], "Staking time has not been started");
        require(block.timestamp <= pool.configs[3], "Staking time has ended"); 
        require(amount > 0, "Staking amount must be greater than 0");
        require(msg.value == taxFee, "Tax fee amount is invalid");

        // Flexible pool update 
        if (pool.poolType == 0) {
            pool.flexData[1] = rewardPerToken(poolId);
            pool.flexData[0] = block.timestamp;
        } else {
            require(amount <= pool.stakingLimit, "Pool staking limit is exceeded");
        }    

        // Update reward
        data.reward = earned(poolId, msg.sender);
        
        // Flexible pool update
        if (pool.poolType == 0) {
            data.rewardPerTokenPaid = pool.flexData[1];
        } else {
            data.lastUpdateTime = block.timestamp;
            data.stakedTime = block.timestamp;
        }
        
        // Update staking amount
        data.balance += amount;
        
        if (totalStakedBalancePerUser[msg.sender] == 0) {
            totalUserStaked += 1;
        }
        // Update user staked balance
        totalStakedBalancePerUser[msg.sender] += amount;
        
        // Update user staked balance by token address
        totalStakedBalanceByToken[pool.stakingToken][msg.sender] += amount; 
        
        if (stakedBalancePerUser[poolId][msg.sender] == 0) {
            pool.totalUserStaked += 1;
        }
        // Update user staked balance by pool
        stakedBalancePerUser[poolId][msg.sender] += amount;
        
        // Update pool staked balance
        pool.stakedBalance += amount;

        // Update staking limit
        if (pool.poolType != 0) {
            pool.stakingLimit -= amount;
        }
        
        // Update total staked balance by token address
        totalAmountStaked[pool.stakingToken] += amount;
        
        // Transfer user's token to the pool
        IERC20(pool.stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        
        // Transfer tax fee
        _transferTaxFee();
        
        emit StakingEvent(amount, msg.sender, poolId, strs[1]);
    }
    
    /** 
     * @dev Take total amount of staked token and reward and stake to the pool
     * @param strs: poolId(0), internalTxID(1)
    */
    function restakeToken(string[] memory strs) external poolExist(strs[0]) notBlocked payable {
        string memory poolId = strs[0];
        PoolInfo storage pool = poolInfo[poolId];
        StakingData storage data = tokenStakingData[poolId][msg.sender];
        
        require(block.timestamp <= pool.configs[3], "Staking time has ended"); 
        require(pool.stakingToken == pool.rewardToken, "Staking token and reward token must be the same");
        require(msg.value == taxFee, "Tax fee amount is invalid");
        
        // If not flexible pool
        if (pool.poolType != 0) {
            require(data.stakedTime + pool.configs[2] * ONE_DAY_IN_SECONDS <= block.timestamp, "Need to wait until staking period ended");
        }
        
        // Flexible pool update
        if (pool.poolType == 0) {
            pool.flexData[1] = rewardPerToken(poolId);
            pool.flexData[0] = block.timestamp;
        }

        // Update reward
        data.reward = earned(poolId, msg.sender);
        
        // Flexible pool update
        if (pool.poolType == 0) {
            data.rewardPerTokenPaid = pool.flexData[1];
        } else {
            data.lastUpdateTime = block.timestamp;
            data.stakedTime = block.timestamp;
        }
        
        // Users can restaked only if reward > 0
        uint256 addingAmount = data.reward;
        require(data.reward > 0, "Reward must be greater than 0");
        require(addingAmount <= pool.stakingLimit, "Pool staking limit is exceeded");
        
        // Update staked balance and reset reward
        data.balance += addingAmount;
        data.reward = 0;

        // Update balance user has staked to the pool
        totalStakedBalancePerUser[msg.sender] += addingAmount;
        
        // Update balance user has staked by token address
        totalStakedBalanceByToken[pool.stakingToken][msg.sender] += addingAmount;
        
        // Update user staked balance to the pool
        stakedBalancePerUser[poolId][msg.sender] += addingAmount; 
        
        // Update pool staked balance
        pool.stakedBalance += addingAmount;
        
        // Update pool staking limit
        pool.stakingLimit -= addingAmount;
        
        // Update amount token user has staked by token address
        totalAmountStaked[pool.stakingToken] += addingAmount;
         
        // Transfer tax fee 
        _transferTaxFee();
         
        emit StakingEvent(data.balance, msg.sender, poolId, strs[1]); 
    }
    
    /**
     * @dev Unstake token of a pool  
     * @param strs: poolId(0), internalTxID(1)
     * @param amount: amount of token user want to unstake
    */
    function unstakeToken(string[] memory strs, uint256 amount) external poolExist(strs[0]) notBlocked payable {
        string memory poolId = strs[0];
        PoolInfo storage pool = poolInfo[poolId];
        StakingData storage data = tokenStakingData[poolId][msg.sender];
        
        // If monthly with unstake period pool
        if (pool.poolType == 3) {
            require(data.stakedTime + pool.configs[2] * ONE_DAY_IN_SECONDS <= block.timestamp, "Need to wait until staking period ended");
        }
        
        require(msg.value == taxFee, "Tax fee amount is invalid");
        require(amount > 0, "Unstake amount must be greater than 0");
        require(data.balance >= amount, "Not enough staking balance");
        
        // Flexible pool update
        if (pool.poolType == 0) {
            pool.flexData[1] = rewardPerToken(poolId);
            pool.flexData[0] = block.timestamp;
        }
        
        // Update reward
        data.reward = earned(poolId, msg.sender);
        
        // Flexible pool update
        if (pool.poolType == 0) {
            data.rewardPerTokenPaid = pool.flexData[1];
        } else {
            data.lastUpdateTime = block.timestamp;
        }
        
        // Update user stake balance
        totalStakedBalancePerUser[msg.sender] -= amount;
        
        // Update user stake balance by token address 
        totalStakedBalanceByToken[pool.stakingToken][msg.sender] += amount;
        if (totalStakedBalancePerUser[msg.sender] == 0) {
            totalUserStaked -= 1;
        }
        
        // Update user stake balance by pool
        stakedBalancePerUser[poolId][msg.sender] -= amount;
        if (stakedBalancePerUser[poolId][msg.sender] == 0) {
            pool.totalUserStaked -= 1;
        }
        
        // Update staked balance
        data.balance -= amount;
        
        // Update pool staked balance
        pool.stakedBalance -= amount; 
        
        // Update total staked balance by token address 
        totalAmountStaked[pool.stakingToken] -= amount;
        
        uint256 reward = 0;
        
        // If user unstake all token and has reward
        if (canGetReward(poolId) && data.reward > 0 && data.balance == 0) {
            reward = data.reward; 
            
            // If fixed time pool can only get partial amount ratio which was set by admin
            if (pool.poolType == 1 && data.stakedTime + pool.configs[2] * ONE_DAY_IN_SECONDS > block.timestamp) { 
                reward = reward * pool.rewardRatio / 100;
            }
            
            // Update pool total reward claimed and reward fund
            pool.totalRewardClaimed += reward;
            pool.rewardFund -= reward;
            
            // Update total reward user has claimed by token address
            totalRewardClaimed[pool.rewardToken] += reward;
            
            // Update pool reward claimed by user
            rewardClaimedPerUser[poolId][msg.sender] += reward;
            
            // Update pool reward claimed by user and token address
            totalRewardClaimedPerUser[pool.rewardToken][msg.sender] += reward;
            
            // Reset reward
            data.reward = 0;
            
            // Transfer reward
            IERC20(pool.rewardToken).safeTransfer(msg.sender, reward);
        }  
        
        // Transfer staking token back to user
        IERC20(pool.stakingToken).safeTransfer(msg.sender, amount);
        
        // Transfer tax fee
        _transferTaxFee();
        
        emit StakingEvent(reward, msg.sender, poolId, strs[1]);
    } 
    
    /**
     * @dev Claim reward when user has staked to the pool for a period of time 
     * @param strs: poolId(0), internalTxID(1)
    */
    function claimReward(string[] memory strs) external poolExist(strs[0]) notBlocked payable { 
        string memory poolId = strs[0];
        PoolInfo storage pool = poolInfo[poolId];
        StakingData storage data = tokenStakingData[poolId][msg.sender]; 
        
        require(msg.value == taxFee, "Tax fee amount is invalid");
        
        // Flexible pool update
        if (pool.poolType == 0) {
            pool.flexData[1] = rewardPerToken(poolId);
            pool.flexData[0] = block.timestamp;
        }
        
        // Update reward        
        data.reward = earned(poolId, msg.sender);
        
        // Flexible pool update
        if (pool.poolType == 0) {
            data.rewardPerTokenPaid = pool.flexData[1];
        } else {
            data.lastUpdateTime = block.timestamp;
        }
        
        uint256 availableAmount = data.reward;
        
        // Fixed time get partial reward
        if (pool.poolType == 1 && data.stakedTime + pool.configs[2] * ONE_DAY_IN_SECONDS > block.timestamp) { 
            availableAmount = availableAmount * pool.rewardRatio / 100;
        }
        
        require(availableAmount > 0, "Reward is 0");
        require(IERC20(pool.rewardToken).balanceOf(address(this)) >= availableAmount, "Pool balance is not enough");
        require(canGetReward(poolId), "Not enough staking time"); 

        // Reset reward
        data.reward = 0;
        
        // Update pool claimed amount
        pool.totalRewardClaimed += availableAmount;
        
        // Update pool reward fund
        pool.rewardFund -= availableAmount; 
        
        // Update reward claimed by token address
        totalRewardClaimed[pool.rewardToken] += availableAmount;
        
        // Update pool reward claimed by user
        rewardClaimedPerUser[poolId][msg.sender] += availableAmount;
        
        // Update pool reward claimed by user and token address
        totalRewardClaimedPerUser[pool.rewardToken][msg.sender] += availableAmount;
        
        // Transfer reward
        IERC20(pool.rewardToken).safeTransfer(msg.sender, availableAmount);

        // Transfer tax fee
        _transferTaxFee();
    
        emit StakingEvent(availableAmount, msg.sender, poolId, strs[1]); 
    } 
    
    /**
     * @dev Check if enough time to claim reward
     * @param poolId: the pool id user has staked
    */
    function canGetReward(string memory poolId) public view returns (bool) {
        PoolInfo memory pool = poolInfo[poolId];
        StakingData memory data = tokenStakingData[poolId][msg.sender];
        
        // Flexible & fixed time pool
        if (pool.poolType == 0 || pool.poolType == 1) return true;
        
        // Pool with staking period
        return data.stakedTime + pool.configs[2] * ONE_DAY_IN_SECONDS <= block.timestamp;
    }

    /**
     * @dev Return amount of reward user can claim
     * @param poolId: the pool id user has staked
     * @param account: wallet address of user
    */
    function earned(string memory poolId, address account) 
        public
        view
        returns (uint256)
    {
        StakingData memory data = tokenStakingData[poolId][account]; 
        if (data.balance == 0) return 0;
        
        PoolInfo memory pool = poolInfo[poolId];
        uint256 amount = 0;
        
        // Flexible pool
        if (pool.poolType == 0) {
            amount = data.balance * (rewardPerToken(poolId) - data.rewardPerTokenPaid) / 1e8 + data.reward;
        } else { 
            amount = (block.timestamp - data.lastUpdateTime) * data.balance * pool.apr / ONE_YEAR_IN_SECONDS / 100;
        }
         
        return pool.rewardFund > amount ? amount : pool.rewardFund;
    }

    /*================================ ADMINISTRATOR FUNCTIONS ================================*/
    
    /**
     * @dev Create pool
     * @param strs: poolId(0), internalTxID(1)
     * @param addr: stakingToken(0), rewardToken(1)
     * @param data: rewardFund(0), apr(1), rewardRatio(2), stakingLimit(3), poolType(4)
     * @param configs: startDate(0), endDate(1), duration(2), endStakedTime(3)
    */
    function createPool(string[] memory strs, address[] memory addr, uint256[] memory data, uint256[] memory configs) external onlyAdmins {
        require(poolInfo[strs[0]].initialFund == 0, "Pool already exists");
        require(data[0] > 0, "Reward fund must be greater than 0");
        require(configs[0] < configs[1], "End date must be greater than start date");
        require(configs[0] < configs[3], "End staking date must be greater than start date");
        
        uint256[] memory flexData = new uint256[](2);
        PoolInfo memory pool = PoolInfo(addr[0], addr[1], 0, 0, data[0], data[0], data[1], 0, data[2], data[3], 1, data[4], flexData, configs);
        poolInfo[strs[0]] = pool;
        totalPoolCreated += 1;
        totalRewardFund[pool.rewardToken] += data[0];
        
        emit PoolUpdated(data[0], msg.sender, strs[0], strs[1]); 
    }
   
    /**
     * @dev Update pool by poolId 
     * @param strs: poolId(0), internalTxID(1)
     * @param newConfigs: startDate(0), endDate(1), endStakingDate(2), stakingLimit(3)
    */
    function updatePool(string[] memory strs, uint256[] memory newConfigs)
        external
        onlyAdmins
        poolExist(strs[0])
    {
        string memory poolId = strs[0];
        PoolInfo storage pool = poolInfo[poolId];
        
        if (newConfigs[0] != 0) {
            require(pool.configs[0] > block.timestamp, "Pool is already published");
            pool.configs[0] = newConfigs[0];
        }
        if (newConfigs[1] != 0) {
            require(newConfigs[1] > pool.configs[0], "End date must be greater than start date");
            require(newConfigs[1] >= block.timestamp, "End date must not be the past");
            pool.configs[1] = newConfigs[1];
        }
        if (newConfigs[2] != 0) {
            require(newConfigs[2] > pool.configs[0], "End staking date must be greater than start date");
            require(newConfigs[2] <= pool.configs[1], "End staking date must be less than or equals to end date");
            pool.configs[3] = newConfigs[2];
        }
        if (newConfigs[3] != 0) {
            uint256 newRewardFund = 0;

            if (pool.poolType != 0) {
                require(newConfigs[3] >= pool.stakingLimit, "New staking limit fund must be greater than or equals to existing staking limit");  
                newRewardFund  = newConfigs[3] * pool.apr / 100;
                pool.stakingLimit = newConfigs[3];
            } else {
                require(newConfigs[3] >= pool.initialFund, "New reward fund must be greater than or equals to existing reward fund");
                newRewardFund = newConfigs[3];   
            }
            
            totalRewardFund[pool.rewardToken] = totalRewardFund[pool.rewardToken] - pool.initialFund + newRewardFund;
            pool.rewardFund = newRewardFund;
            pool.initialFund = newRewardFund;
        }
        
        emit PoolUpdated(pool.initialFund, msg.sender, strs[0], strs[1]);
    }
    
    /**
     * @dev Return annual percentage rate of a pool
     * @param poolId: Pool id
    */
    function apr(string memory poolId) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[poolId];
        
        // If not flexible pool
        if (pool.poolType != 0) return pool.apr; 
        
        // Flexible pool
        uint256 poolDuration = pool.configs[1] - pool.configs[0];
        if (pool.stakedBalance == 0 || poolDuration == 0) return 0;
        
        return (ONE_YEAR_IN_SECONDS * pool.rewardFund / poolDuration - pool.totalRewardClaimed) * 100 / pool.stakedBalance; 
    }
    
    /**
     * @dev Return amount of reward token distibuted per second
     * @param poolId: Pool id
    */
    function rewardPerToken(string memory poolId) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[poolId];
        
        require(pool.poolType == 0, "Only flexible pool");
        
        // poolDuration = poolEndDate - poolStartDate
        uint256 poolDuration = pool.configs[1] - pool.configs[0]; 
        
        // Get current timestamp, if currentTimestamp > poolEndDate then poolEndDate will be currentTimestamp
        uint256 currentTimestamp = block.timestamp < pool.configs[1] ? block.timestamp : pool.configs[1];
        
        // If stakeBalance = 0 or poolDuration = 0
        if (pool.stakedBalance == 0 || poolDuration == 0) return 0;
        
        // If the pool has ended then stop calculate reward per token
        if (currentTimestamp <= pool.flexData[0]) return pool.flexData[1];
        
        // result = result * 1e8 for zero prevention
        uint256 rewardPool = pool.rewardFund * (currentTimestamp - pool.flexData[0]) * 1e8;
        
        // newRewardPerToken = rewardPerToken(newPeriod) + lastRewardPertoken          
        return rewardPool / (poolDuration * pool.stakedBalance) + pool.flexData[1];
    }
    
    /** 
     * @dev Emercency withdraw token for users
     * @param _poolId: the pool id user has staked
     * @param _account: wallet address of user
    */
    function emercencyWithdrawToken(string memory _poolId, address _account) external {
        PoolInfo memory pool = poolInfo[_poolId];
        StakingData memory data = tokenStakingData[_poolId][_account];
        require(data.balance > 0, "Staked balance is 0");
        
        // Transfer staking token back to user
        IERC20(pool.stakingToken).safeTransfer(_account, data.balance);
        
        uint256 amount = data.balance;

        // Flexible pool update
        if (pool.poolType == 0) {
            pool.flexData[1] = rewardPerToken(_poolId);
            pool.flexData[0] = block.timestamp;
        }
        
        // Update user stake balance
        totalStakedBalancePerUser[msg.sender] -= amount;
        
        // Update user stake balance by token address 
        totalStakedBalanceByToken[pool.stakingToken][msg.sender] += amount;
        if (totalStakedBalancePerUser[msg.sender] == 0) {
            totalUserStaked -= 1;
        }
        
        // Update user stake balance by pool
        stakedBalancePerUser[_poolId][msg.sender] -= amount;
        if (stakedBalancePerUser[_poolId][msg.sender] == 0) {
            pool.totalUserStaked -= 1;
        }
        
        // Update pool staked balance
        pool.stakedBalance -= amount; 
        
        // Update total staked balance by token address 
        totalAmountStaked[pool.stakingToken] -= amount;

        // Delete data
        delete tokenStakingData[_poolId][_account];
    }
    
    /**
     * @dev Withdraw fund admin has sent to the pool
     * @param _tokenAddress: the token contract owner want to withdraw fund
     * @param _account: the account which is used to receive fund
     * @param _amount: the amount contract owner want to withdraw
    */
    function withdrawFund(address _tokenAddress, address _account, uint256 _amount) external {
        require(IERC20(_tokenAddress).balanceOf(address(this)) >= _amount, "Pool not has enough balance");
        
        // Transfer fund back to account
        IERC20(_tokenAddress).safeTransfer(_account, _amount);
    }
    
    /**
     * @dev Set tax fee paid by native token when users stake, unstake, restake and claim
     * @param _taxFee: amount users have to pay when call any of these functions 
    */
    function setTaxFee(uint256 _taxFee) external {
        taxFee = _taxFee;

        emit TaxFeeSet(msg.sender, _taxFee);
    }
    
    /**
     * @dev Set recipient address which is used to receive tax fee
    */
    function setFeeRecipientAddress(address _feeRecipientAddress) external {
        feeRecipientAddress = _feeRecipientAddress;

        emit FeeRecipientSet(msg.sender, _feeRecipientAddress);
    }
    
    /**
     * @dev Transfer tax fee 
    */
    function _transferTaxFee() internal {
        // If recipientAddress and taxFee are set
        if (feeRecipientAddress != address(0) && taxFee > 0) {
            payable(feeRecipientAddress).transfer(taxFee);
        }
    }
    
    /**
     * @dev Contract owner set admin for execute administrator functions
     * @param _address: wallet address of admin
     * @param _value: true/false
    */
    function setAdmin(address _address, bool _value) external { 
        adminList[_address] = _value;

        emit AdminSet(_address, _value);
    } 

    /**
     * @dev Check if a wallet address is admin or not
     * @param _address: wallet address of the user
    */
    function isAdmin(address _address) external view returns (bool) {
        return adminList[_address];
    }

    /**
     * @dev Block users
     * @param _address: wallet address of user
     * @param _value: true/false
    */
    function setBlacklist(address _address, bool _value) external onlyAdmins {
        blackList[_address] = _value;

        emit BlacklistSet(_address, _value);
    }
    
    /**
     * @dev Check if a user has been blocked
     * @param _address: user wallet 
    */
    function isBlackList(address _address) external view returns (bool) {
        return blackList[_address];
    }
    
    /**
     * @dev Set pool active/deactive
     * @param _poolId: the pool id
     * @param _value: true/false
    */
    function setPoolActive(string memory _poolId, uint256 _value) external onlyAdmins {
        poolInfo[_poolId].active = _value;
        
        emit PoolActivationSet(msg.sender, _poolId, _value);
    }
}