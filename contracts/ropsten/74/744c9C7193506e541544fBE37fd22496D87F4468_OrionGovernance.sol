// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IOrionGovernance.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract OrionGovernance is IOrionGovernance, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserData
    {
        uint56 balance;
        uint56 locked_balance;
    }

    struct UserVault
    {
        uint56 amount;
        uint64 created_time;
    }

    ///////////////////////////////////////////////////
    //  Data fields
    //  NB: Only add new fields BELOW any fields in this section

    //  Must be 8-digit token
    IERC20 public staking_token_;

    //  Staking balances
    mapping(address => UserData) public balances_;

    //  Voting contract address (now just 1 voting contract supported)
    address public voting_contract_address_;

    //  Total balance
    uint56 public total_balance_;

    //  TODO: decrease writable uint256 count
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    //  Just voting for proposal data
    mapping(address => uint56) public user_burn_votes_;
    uint64 public burn_vote_end_;
    uint56 public total_votes_burn_;
    uint56 public total_votes_dont_burn_;

    //  Vaults of users for withdrawal
    mapping(address => UserVault[]) public vaults_;
    uint64 public extra_fee_seconds;
    uint16 public extra_fee_percent;  //  0 - 1000, where 1000
    uint16 public basic_fee_percent;  //  0 - 999

    uint56 public fee_total;

    //  Add new data fields there....
    //      ...

    //  End of data fields
    /////////////////////////////////////////////////////

    //  Initializer
    function initialize(address staking_token) public initializer {
        require(staking_token != address(0), "OGI0");
        OwnableUpgradeable.__Ownable_init();
        staking_token_ = IERC20(staking_token);
    }

    function setVotingContractAddress(address voting_contract_address) external onlyOwner
    {
        voting_contract_address_ = voting_contract_address;
    }

    function lastTimeRewardApplicable() override public view returns (uint256) {
        //  return Math.min(block.timestamp, periodFinish);
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() override public view returns (uint256) {
        if (total_balance_ == 0) {
            return rewardPerTokenStored;
        }
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(uint(total_balance_))
        );
    }

    function earned(address account) override public view returns (uint256) {
        return uint(balances_[account].balance).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() override external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    //  Stake
    function stake(uint56 adding_amount) override public nonReentrant updateReward(msg.sender)
    {
        require(adding_amount > 0, "CNS0");
        staking_token_.safeTransferFrom(msg.sender, address(this), adding_amount);

        uint56 balance = balances_[msg.sender].balance;
        balance += adding_amount;
        require(balance >= adding_amount, "OF(1)");
        balances_[msg.sender].balance = balance;

        uint56 total_balance = total_balance_;
        total_balance += adding_amount;
        require(total_balance >= adding_amount, "OF(3)");  //  Maybe not needed
        total_balance_ = total_balance;

        emit Staked(msg.sender, uint256(adding_amount));
    }

    // Unstake
    function withdraw(uint56 removing_amount) override public nonReentrant updateReward(msg.sender)
    {
        require(removing_amount > 0, "CNW0");

        uint56 balance = balances_[msg.sender].balance;
        require(balance >= removing_amount, "CNW1");
        balance -= removing_amount;
        balances_[msg.sender].balance= balance;

        uint56 total_balance = total_balance_;
        require(total_balance >= removing_amount, "CNW2");
        total_balance -= removing_amount;
        total_balance_ = total_balance;

        uint56 locked_balance = balances_[msg.sender].locked_balance;
        require(locked_balance <= balance, "CNW3");

        if(voteBurnAvailable())
            //  Additional checks
            require(user_burn_votes_[msg.sender] <= balance, "CNW4");

        //  staking_token_.safeTransfer(msg.sender, removing_amount);
        vaults_[msg.sender].push(UserVault({
            amount: removing_amount,
            created_time: uint64(block.timestamp)}));

        emit Withdrawn(msg.sender, uint256(removing_amount));
    }

    function vaultWithdraw(uint index) public nonReentrant
    {
        //  ? Do we need extra check there
        UserVault memory vault = vaults_[msg.sender][index];
        uint fee_percent = basic_fee_percent;
        if(vault.created_time + extra_fee_seconds > block.timestamp)
            //  Premature withdrawal, so adjust amount (reduce by percent)
            fee_percent += extra_fee_percent;

        uint vault_amount = uint(vault.amount);
        uint fee_orn = vault_amount.mul(fee_percent).div(1000);

        fee_total += uint56(fee_orn);

        uint len = vaults_[msg.sender].length;

        if(index < len-1)
            vaults_[msg.sender][index] = vaults_[msg.sender][len-1];

        vaults_[msg.sender].pop();

        staking_token_.safeTransfer(msg.sender, vault_amount.sub(fee_orn));
    }

    //  Only owner could set vault parameters
    function setVaultParameters(uint16 extra_fee_percent_, uint64 extra_fee_seconds_, uint16 basic_fee_percent_) external onlyOwner
    {
        require(extra_fee_percent_ + basic_fee_percent_ < 1000, "VF_1");
        extra_fee_percent = extra_fee_percent_;
        extra_fee_seconds = extra_fee_seconds_;
        basic_fee_percent = basic_fee_percent_;
    }

    function burn(uint56 burn_size) external onlyOwner
    {
        require(burn_size <= fee_total, "OW_CNB");
        fee_total -= burn_size;
        staking_token_.safeTransfer(0x000000000000000000000000000000000000dEaD, burn_size);
    }

    function getReward() virtual override public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            staking_token_.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() virtual override external {
        withdraw(balances_[msg.sender].balance);
        getReward();
    }

    function acceptNewLockAmount(
        address user,
        uint56 new_lock_amount
    ) external override onlyVotingContract
    {
        uint56 balance = balances_[user].balance;
        require(balance >= new_lock_amount, "Cannot lock");
        balances_[user].locked_balance = new_lock_amount;
    }

    function acceptLock(
        address user,
        uint56 lock_increase_amount
    )  external override onlyVotingContract
    {
        require(lock_increase_amount > 0, "Can't inc by 0");

        uint56 balance = balances_[user].balance;
        uint56 locked_balance = balances_[user].locked_balance;

        locked_balance += lock_increase_amount;
        require(locked_balance >= lock_increase_amount, "OF(4)");
        require(locked_balance <= balance, "can't lock more");

        balances_[user].locked_balance = locked_balance;
    }

    function acceptUnlock(
        address user,
        uint56 lock_decrease_amount
    )  external override onlyVotingContract
    {
        require(lock_decrease_amount > 0, "Can't dec by 0");

        uint56 locked_balance = balances_[user].locked_balance;
        require(locked_balance >= lock_decrease_amount, "Can't unlock more");

        locked_balance -= lock_decrease_amount;
        balances_[user].locked_balance = locked_balance;
    }

    //  Views
    function getBalance(address user) public view returns(uint56)
    {
        return balances_[user].balance;
    }

    function getLockedBalance(address user) public view returns(uint56)
    {
        return balances_[user].locked_balance;
    }

    function getTotalBalance() public view returns(uint56)
    {
        return total_balance_;
    }

    function getTotalLockedBalance(address user) public view returns(uint56)
    {
        uint56 locked_balance = balances_[user].locked_balance;
        if(voteBurnAvailable())
        {
            uint56 burn_vote_balance = user_burn_votes_[user];
            if(burn_vote_balance > locked_balance)
                locked_balance = burn_vote_balance;
        }

        return locked_balance;
    }

    function getVaults(address wallet) public view returns(UserVault[] memory)
    {
        return vaults_[wallet];
    }

    function getAvailableWithdrawBalance(address user) public view returns(uint56)
    {
        return balances_[user].balance - getTotalLockedBalance(user);
    }
    
    //  Root methods
    function notifyRewardAmount(uint256 reward, uint256 _rewardsDuration) external onlyOwner updateReward(address(0)) {
        require((_rewardsDuration> 1 days) && (_rewardsDuration < 365 days), "Incorrect rewards duration");
        rewardsDuration = _rewardsDuration;
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = staking_token_.balanceOf(address(this)); //  TODO: review
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    function emergencyAssetWithdrawal(address asset) external onlyOwner {
        IERC20 token = IERC20(asset);
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    //  Voting for burn
    function voteBurn(uint56 voting_amount, bool vote_for_burn) public
    {
        require(voteBurnAvailable(), "VB_FIN");
        uint56 balance = balances_[msg.sender].balance;
        uint56 voted_balance = user_burn_votes_[msg.sender];
        require(balance >= voted_balance, "VB_OF");
        require(voting_amount <= balance - voted_balance, "VB_NE_ORN");
        user_burn_votes_[msg.sender] = voted_balance + voting_amount;
        if(vote_for_burn)
            total_votes_burn_ += voting_amount;
        else
            total_votes_dont_burn_ += voting_amount;
    }

    //  Is voting available
    function voteBurnAvailable() public view returns(bool)
    {
        return (block.timestamp <= burn_vote_end_);
    }

    //  Only owner could set vote end
    function setBurnVoteEnd(uint64 burn_vote_end) external onlyOwner
    {
        burn_vote_end_ = burn_vote_end;
    }

    ////////////////////////
    //  Modifiers
    modifier onlyVotingContract()
    {
        require(msg.sender == voting_contract_address_, "must be voting");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    //  Events
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
}