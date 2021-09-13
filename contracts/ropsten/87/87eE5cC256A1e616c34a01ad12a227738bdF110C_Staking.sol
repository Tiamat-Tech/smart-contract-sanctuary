pragma solidity 0.8.6;

// SPDX-License-Identifier: MIT



import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @notice Info of each stake
     * @param amount: How many Gate tokens the user has provided
     * @param rewardDebt: Reward debt. See explanation below
     * @param feeDebt: How many feeRewards the user received
     * @param stakeBlock: Last staking block
     */
    struct Stake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 feeDebt;
        uint256 stakeBlock;
    }

    uint256 public accRewardPerShare; // Accumulated rewards per share, times 1e12. See below.
    uint256 public accFeeRewardPerShare; // Accumulated rewards per share,times 1e12. For feeDistribution
    uint256 public lastRewardBlock; // Last reward distribution block
    uint256 public totalStaked; // Staked tokens amount
    uint256 public blockPerDay; // Approximate number of blocks per day
    uint256 public rewardPerBlock; // Reward for every block
    uint256 public startBlock; // Block starting from which rewards will be distributed
    uint256 public endBlock; // Block starting from which rewards will no longer be distributed
    uint256 public lastFeeDistributionBlock; // Last feeDistribution block
    uint256 public minStakingAmount = 1000000000000000000; // Minimal amount for staking
    uint256 public constant lockPeriod = 300; // Number of blocks that must be passed to get the opportunity for claim and unStake
    address public compound; // Compound contract Address

    // Info of each user that stakes Gate tokens.
    mapping(address => Stake[]) public stakes;
    // Gate token
    IERC20 public stakedToken;

    event Staked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event FeeDistributed(uint256 feeDistributionBlock, uint256 amount);
    event FeesClaimed(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 index);

    constructor(
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) {
        require(
            address(_rewardToken) != address(0x0),
            "Staking::Reward token can't be zero"
        );
        stakedToken = IERC20(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        blockPerDay = 10;
    }

    modifier onlyCompound() {
        require(msg.sender == compound, "Staking:: Only compound");
        _;
    }

    /**
     * @notice Fee reward distribution. Rewards will be distributed according to the every user stake amounts
     * @param _amount: reward amount
     */
    function feeDistribution(uint256 _amount) external onlyOwner {
        stakedToken.transferFrom(msg.sender, address(this), _amount);
        uint256 onlyStakesFromStaking = totalStaked;
        if(stakes[compound].length > 0){
            onlyStakesFromStaking = totalStaked - stakes[compound][0].amount;
        }
        accFeeRewardPerShare =
            accFeeRewardPerShare +
            (_amount * 1e12) /
            onlyStakesFromStaking;
        lastFeeDistributionBlock = block.number;

        emit FeeDistributed(block.number, _amount);
    }

    /**
     * @notice Stake LP tokens to Farming for reward allocation
     * @param _amount: the amount of Gate tokens that should be stakeed
     */
    function stake(uint256 _amount) external {
        require(
            _amount >= minStakingAmount,
            "Staking::Staking amount must be greater then min staking amount"
        );
        distributeReward();
        stakedToken.safeTransferFrom(msg.sender, address(this), _amount);
        _stake(_amount);
    }

    /**
     * @notice Function which send accumulated reward tokens to messege sender
     */
    function claim() external {
        uint256 length = stakes[msg.sender].length;
        distributeReward();
        for (uint256 index = 0; index < length; index++) {
            if (stakes[msg.sender][index].amount > 0) {
                _claim(index);
            }
        }
    }

    /**
     * @notice Function which unStake Gate tokens to messege sender with the given amount
     * @param _amount: the amount of Gate tokens that should be unStaken
     */
    function unstake(uint256 _amount, uint256 _index) external {
        require(
            stakes[msg.sender][_index].amount >= _amount,
            "Staking::staked amount less than required amount"
        );
        require(
            stakes[msg.sender][_index].stakeBlock + lockPeriod < block.number,
            "Staking::lockPeriod don't passed"
        );
        distributeReward();
        _unstake(_amount, _index);
    }

    function autoCompStake(uint256 _amount) external onlyCompound {
        require(
            _amount >= minStakingAmount,
            "Staking::Staking amount must be greater then min staking amount"
        );
        distributeReward();
        if (stakes[msg.sender].length == 0) {
            if (_amount > 0) {
                stakedToken.safeTransferFrom(
                    msg.sender,
                    address(this),
                    _amount
                );

                stakes[msg.sender].push(
                    Stake({
                        amount: _amount,
                        rewardDebt: (_amount * accRewardPerShare) / 1e12,
                        feeDebt: (_amount * accFeeRewardPerShare) / 1e12,
                        stakeBlock: block.number
                    })
                );
                totalStaked += _amount;
                emit Staked(msg.sender, _amount);
            }
            return;
        }
        Stake storage stakeInfo = stakes[msg.sender][0];

        if (stakeInfo.amount > 0) {
            uint256 pending = (stakeInfo.amount * accRewardPerShare) /
                1e12 -
                stakeInfo.rewardDebt;
            if (pending > 0) {
                safeRewardTransfer(msg.sender, pending);
            }
        }

        if (_amount > 0) {      
            stakedToken.safeTransferFrom(msg.sender, address(this), _amount);
            stakeInfo.amount += _amount;
        }
        totalStaked += _amount;
        stakeInfo.rewardDebt = (stakeInfo.amount * accRewardPerShare) / 1e12;
        emit Staked(msg.sender, _amount);
    }

    function autoCompUnstake(uint256 _amount) external onlyCompound {
        Stake storage stakeInfo = stakes[msg.sender][0];
        require(
            stakeInfo.amount >= _amount,
            "Staking::staked amount less than required amount"
        );
        distributeReward();
        uint256 pending = (stakeInfo.amount * accRewardPerShare) /
            1e12 -
            stakeInfo.rewardDebt;

        if (pending > 0) {
            safeRewardTransfer(msg.sender, pending);
        }

        if (_amount > 0) {
            stakeInfo.amount -= _amount;
            totalStaked -= _amount;
            safeRewardTransfer(msg.sender, _amount);
        }
        stakeInfo.rewardDebt = (stakeInfo.amount * accRewardPerShare) / 1e12;
    }

    /**
     * @notice View function to see how many rewards will be received for block interval
     * @param _from: block from which to start counting
     * @param _to: block on which to end the count
     */
    function getReward(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_from < startBlock) {
            _from = startBlock;
        }

        if (_to > endBlock) {
            _to = endBlock;
        }

        require(_from <= _to, "Staking:: Incorrect date");

        return rewardPerBlock * (_to - _from);
    }

    /**
     * @notice View function to see pending rewards on frontend
     * @param _user: user address for which reward must be calculated
     * @return Return reward for user
     */
    function pendingReward(address _user) public view returns (uint256) {
        uint256 accRewardPerShareLocal = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked != 0) {
            accRewardPerShareLocal =
                accRewardPerShare +
                ((getReward(lastRewardBlock, block.number) * 1e12) /
                    totalStaked);
        }
        uint256 length = stakes[_user].length;
        uint256 pending;
        for (uint256 index = 0; index < length; index++) {
            Stake memory stakeInfo = stakes[_user][index];
            pending +=
                (stakeInfo.amount * accRewardPerShareLocal) /
                1e12 -
                stakeInfo.rewardDebt;
        }
        return pending;
    }

    function pendingFee(address _user) public view returns (uint256) {
        uint256 length = stakes[_user].length;
        uint256 pendingFees;
        for (uint256 index = 0; index < length; index++) {
            Stake memory stakeInfo = stakes[_user][index];
            pendingFees +=
                (stakeInfo.amount * accFeeRewardPerShare) /
                1e12 -
                stakeInfo.feeDebt;
        }
        return pendingFees;
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date
     */
    function distributeReward() public {
        if (block.number <= lastRewardBlock) {
            // lastRewardBlock -> startBLock
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        accRewardPerShare =
            accRewardPerShare +
            ((getReward(lastRewardBlock, block.number) * 1e12) / totalStaked);

        lastRewardBlock = block.number;
    }

    function setCompoundAddress(address _compound) public onlyOwner {
        compound = _compound;
    }

    /**
     * @notice Function which transfer reward tokens to _to with the given amount
     * @param _to: transfer reciver address
     * @param _amount: amount of reward token which should be transfer
     */
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            uint256 rewardTokenBal = stakedToken.balanceOf(address(this)) -
                totalStaked;
            if (_amount > rewardTokenBal) {
                stakedToken.transfer(_to, rewardTokenBal);
                return;
            }
            stakedToken.transfer(_to, _amount);
        }
    }

    function getUserStakes(address _user) public view returns (Stake[] memory) {
        return stakes[_user];
    }

    function _stake(uint256 _amount) private {
        Stake memory newStake;
        newStake.amount = _amount;
        totalStaked += _amount;
        newStake.stakeBlock = block.number;
        newStake.rewardDebt = (_amount * accRewardPerShare) / 1e12;
        newStake.feeDebt = (_amount * accFeeRewardPerShare) / 1e12;

        stakes[msg.sender].push(newStake);

        emit Staked(msg.sender, _amount);
    }

    function _claim(uint256 _index) private {
        Stake storage stakeInfo = stakes[msg.sender][_index];
        uint256 pending;
        uint256 feeReward;
        if (stakeInfo.stakeBlock + lockPeriod < block.number) {
            pending =
                (stakeInfo.amount * accRewardPerShare) /
                1e12 -
                stakeInfo.rewardDebt;

            stakeInfo.rewardDebt =
                (stakeInfo.amount * accRewardPerShare) /
                1e12;
        }
        if (lastFeeDistributionBlock + lockPeriod < block.number) {
            feeReward =
                (stakeInfo.amount * accFeeRewardPerShare) /
                1e12 -
                stakeInfo.feeDebt;

            stakeInfo.feeDebt =
                (stakeInfo.amount * accFeeRewardPerShare) /
                1e12;
        }
        safeRewardTransfer(msg.sender, pending + feeReward);
        emit Claimed(msg.sender, pending + feeReward);
    }

    function _unstake(uint256 _amount, uint256 _index) private {
        Stake storage stakeInfo = stakes[msg.sender][_index];
        _claim(_index);
        totalStaked -= _amount;
        stakeInfo.amount -= _amount;
        stakeInfo.rewardDebt = (stakeInfo.amount * accRewardPerShare) / 1e12;
        stakeInfo.feeDebt = (stakeInfo.amount * accFeeRewardPerShare) / 1e12;
        stakedToken.safeTransfer(address(msg.sender), _amount);
        emit Unstaked(msg.sender, _amount, _index);
    }
}