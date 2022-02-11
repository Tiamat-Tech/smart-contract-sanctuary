//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/AccessLevel.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract StakePIFV2 is UUPSUpgradeable, AccessLevel,ReentrancyGuardUpgradeable {
    
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    IERC20Upgradeable public stakingToken;
    IERC20Upgradeable public rewardToken;
 
    event Unstake(uint256 stakeId, address unstaker);
    event Stake(uint256 stakeId, address staker);
    event SetStakingEnabled(bool stakingEnabled, address sender);
    event SetMaxLoss(uint maxLoss, address sender);   
    event SetRewardRate(uint rewardRate, address sender);   
    event SetMinClaimPeriod(uint rewardRate, address sender);
    event SetCommunityAddress(address communityAddress, address sender);     

    struct StakingInfo{
        address owner;
        uint id;
        uint timeToUnlock;
        uint stakingTime;
        uint tokensStaked;
        uint tokensStakedWithBonus;
    }

    uint public maxLoss;
    bool public stakingEnabled;
    uint public rewardRate; 
    uint private constant DIVISOR = 1e11;
    uint private constant DECIMAL = 1e18;
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;
    uint public minClaimPeriod;
    address public communityAddress;
    uint public uniqueAddressesStaked;
    uint public totalTokensStaked;
    uint public totalRewardsClaimed;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;
    mapping(uint => uint) public bonusTokenMultiplier;
    mapping(address => mapping(uint => StakingInfo)) public stakingInfoForAddress;
    mapping(address => uint) public tokensStakedByAddress;
    mapping(address => uint) public tokensStakedWithBonusByAddress;
    mapping(address => uint) public totalRewardsClaimedByAddress;

    uint public totalTokensStakedWithBonusTokens;
    mapping(address => uint) public balances;
    mapping(address => uint) public lastClaimedTimestamp;
    mapping(address => uint) public stakingNonce;


    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    
    /** Initializes the staking contract
    @param tokenAddress_ the token address that will be staked
    @param rewardToken_ the token address that will be rewarded
    @param owner_ the address of the contract owner
    @param communityAddress_ the address the community tokens will be gathering
    @param minClaimPeriod_ the period limit for claiming rewards
    @param rewardRate_ the reward rate to set up
    */

    // we add change community address 
    function initialize(address tokenAddress_, address rewardToken_, address owner_, address communityAddress_, uint minClaimPeriod_, uint rewardRate_) initializer external {
        require(tokenAddress_ != address(0),"INVALID_TOKEN_ADDRESS");
        require(rewardToken_ != address(0),"INVALID_TOKEN_ADDRESS");
        require(owner_ != address(0),"INVALID_OWNER_ADDRESS");
        require(communityAddress_ != address(0),"INVALID_COMMUNITY_ADDRESS");
        require(minClaimPeriod_ > 0,"INVALID_MIN_CLAIM_PERIOD");
        require(rewardRate_ > 0,"INVALID_REWARD_RATE");

        __AccessLevel_init(owner_);
        __ReentrancyGuard_init();
        stakingToken = IERC20Upgradeable(tokenAddress_);
        rewardToken = IERC20Upgradeable(rewardToken_);
        stakingEnabled = true;
        communityAddress = communityAddress_;
        minClaimPeriod = minClaimPeriod_;
        rewardRate = rewardRate_;
    }

    /** Computes the reward per token
    */
    function rewardPerToken() public view returns (uint) {
        if (totalTokensStakedWithBonusTokens == 0) {
            return 0;
        }

        return
            rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * DECIMAL) / totalTokensStakedWithBonusTokens);
    }

    /** Computes the earned amount thus far by the address
    @param account_ account to get the earned ammount for
    */
    function earned(address account_) public view returns (uint) {
        return
            ((balances[account_] *
                (rewardPerToken() - userRewardPerTokenPaid[account_])) / DECIMAL) +
            rewards[account_];
    }

    /** modifier that updates and computes the correct internal variables
    @param account_ the account called for
    */
    modifier updateReward(address account_) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        rewards[account_] = earned(account_);
        userRewardPerTokenPaid[account_] = rewardPerTokenStored;
        _;
    }

    /** Staking function
    @param amount_ the amount to stake
    @param lockTime_ the lock time to lock the stake for
    */
    function stake(uint amount_, uint lockTime_) external nonReentrant() updateReward(msg.sender) {
        require(lockTime_ > 0, "LOCK_TIME_INVALID");
        require(stakingEnabled , "STAKING_DISABLED");
        require(amount_ > 0, "CANNOT_STAKE_0");
        require(bonusTokenMultiplier[lockTime_] > 0, "LOCK_TIME_ERROR");

        if(stakingNonce[msg.sender] == 0){
            uniqueAddressesStaked++;
        }
        
        stakingNonce[msg.sender]++;
    
        uint tokensWithBonus = amount_ * bonusTokenMultiplier[lockTime_] / DIVISOR;

        totalTokensStaked += amount_;
        totalTokensStakedWithBonusTokens += tokensWithBonus;
        balances[msg.sender] += tokensWithBonus;
        tokensStakedByAddress[msg.sender] += amount_;
        tokensStakedWithBonusByAddress[msg.sender] += tokensWithBonus;
        lastClaimedTimestamp[msg.sender] = block.timestamp;

        StakingInfo storage data = stakingInfoForAddress[msg.sender][stakingNonce[msg.sender]];
        data.owner = msg.sender;
        data.stakingTime = block.timestamp;
        data.tokensStaked = amount_;
        data.timeToUnlock = block.timestamp + lockTime_;
        data.tokensStakedWithBonus = tokensWithBonus;
        data.id = stakingNonce[msg.sender];

        emit Stake(stakingNonce[msg.sender], msg.sender);
       
        stakingToken.safeTransferFrom(msg.sender, address(this), amount_);
    
    }

    /** Unstake function
    @param stakeId_ the stake id to unstake
    */
    function unstake(uint stakeId_) external nonReentrant() updateReward(msg.sender) {
        getRewardInternal();
        StakingInfo storage info = stakingInfoForAddress[msg.sender][stakeId_];
        require(stakeId_ > 0 && info.id == stakeId_,"INVALID_STAKE_ID");
        
        totalTokensStaked -= info.tokensStaked;
        totalTokensStakedWithBonusTokens -= info.tokensStakedWithBonus;
        balances[msg.sender] -= info.tokensStakedWithBonus;
        tokensStakedByAddress[msg.sender] -= info.tokensStaked;
        tokensStakedWithBonusByAddress[msg.sender] -= info.tokensStakedWithBonus;

        uint tokensLost = 0;
        uint tokensTotal = info.tokensStaked;
        
        if(info.timeToUnlock > block.timestamp) {
            uint maxTime = info.timeToUnlock - info.stakingTime;
            uint lossPercentage = maxLoss - (block.timestamp - info.stakingTime) * maxLoss / maxTime;
            tokensLost = lossPercentage * info.tokensStaked / DIVISOR;
            stakingToken.safeTransfer(communityAddress, tokensLost);
           
        }

        delete stakingInfoForAddress[msg.sender][stakeId_];
        emit Unstake(stakeId_, msg.sender);

        stakingToken.safeTransfer(msg.sender, tokensTotal - tokensLost);
        
    }

    /** The function called to get the reward for all the user stakes
    */
    function getReward() external nonReentrant() updateReward(msg.sender) {
        require(lastClaimedTimestamp[msg.sender] + minClaimPeriod <= block.timestamp,
         "CANNOT_CLAIM_REWARDS_YET");
        getRewardInternal();
    }

    /** The function called to get the reward for all the user stakes
    This function does not check for min claimPeriod
    */
    function getRewardInternal() internal {
        lastClaimedTimestamp[msg.sender] = block.timestamp;
        uint reward = rewards[msg.sender];
        require(stakingToken.balanceOf(address(this)) >= reward ,"BALANCE_NOT_ENOUGH");

        rewards[msg.sender] = 0;
        totalRewardsClaimed += reward;
        totalRewardsClaimedByAddress[msg.sender] += reward;
        rewardToken.safeTransfer(msg.sender, reward);
    }

    /** 
    @dev Sets the bonus multipliers and the allowed locking durations
    @param durations_ an array of the allowed staking durations
    @param mutiplier_ the multiplier dor all staking durations
    */
    function setBonusMultiplier(uint[] calldata durations_, uint[] calldata mutiplier_) 
    external onlyRole(OPERATOR_ROLE) {
        require(durations_.length == mutiplier_.length, "INVALID_DURATIONS_MULTIPLIER_LENGTH");
        for(uint256 i = 0; i < durations_.length; i++) {
            require(mutiplier_[i] >= DIVISOR, "INVALID_MULTIPLIER");
            bonusTokenMultiplier[durations_[i]] = mutiplier_[i];
        }
    }

    /** 
    @dev Sets the staking enabled flag
    @param stakingEnabled_ weather or not staking should be enabled
    */
    function setStakingEnabled(bool stakingEnabled_) external onlyRole(OPERATOR_ROLE) {
        stakingEnabled = stakingEnabled_;

        emit SetStakingEnabled(stakingEnabled_,msg.sender);
    }

    /** 
    @dev Sets the maximum possible loss
    @param maxLoss_ the max loss possibe for an early unstake
    */
    function setMaxLoss(uint maxLoss_) external onlyRole(OPERATOR_ROLE) {
        require(maxLoss_ > 0,"INVALID_MAX_LOSS");
        require(maxLoss_ < DIVISOR, "INVALID_MAX_LOSS");
        maxLoss = maxLoss_;

        emit SetMaxLoss(maxLoss_,msg.sender);
    }

    /** 
    @dev Sets the new reward rate
    @param rewardRate_ the reward rate to set up
    */
    function setRewardRate(uint rewardRate_) external onlyRole(OPERATOR_ROLE) {
        require(rewardRate_ > 0, "INVALID_REWARD_RATE");
        rewardRate = rewardRate_;

        emit SetRewardRate(rewardRate_,msg.sender);
    }

    /** 
    @dev Sets the new minimum claim period
    @param minClaimPeriod_ the period limit for claiming rewards
    */
    function setMinClaimPeriod(uint minClaimPeriod_) external onlyRole(OPERATOR_ROLE) {
        require(minClaimPeriod_ > 0,"INVALID_MIN_CLAIM_PERIOD");
        minClaimPeriod = minClaimPeriod_;

        emit SetMinClaimPeriod(minClaimPeriod_,msg.sender);
    }

    /** 
    @dev Sets commuity address
    @param communityAddress_ the address the community tokens will be gathering
    */
    function setCommunityAddress_(address communityAddress_) external onlyRole(OPERATOR_ROLE) {
        communityAddress = communityAddress_;

        emit SetCommunityAddress(communityAddress,msg.sender);
    }

    /**
    @dev Returns all the user stakes
    @param userAddress_ returns all the user stakes
    */
    function getAllAddressStakes(address userAddress_) public view returns(StakingInfo[] memory)
    {
        StakingInfo[] memory stakings = new StakingInfo[](stakingNonce[userAddress_]);
        for (uint i = 0; i < stakingNonce[userAddress_]; i++) {
            StakingInfo memory staking = stakingInfoForAddress[userAddress_][i];
            if(staking.tokensStaked > 0){
                stakings[i] = staking;
            }
        }
        return stakings;
    }

    function version() external pure returns(string memory){
        return "2";
    }
    
}