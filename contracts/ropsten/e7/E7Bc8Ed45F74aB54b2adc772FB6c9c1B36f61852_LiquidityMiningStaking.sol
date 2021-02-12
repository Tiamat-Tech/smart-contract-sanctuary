// SPDX-License-Identifier: MIT
pragma solidity =0.7.4;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityMiningStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    uint256 public rewardPerBlock;
    uint256 public firstBlockWithReward;
    uint256 public lastBlockWithReward;
    uint256 public lastUpdateBlock;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public totalStaked;
    mapping(address => uint256) public staked;

    event RewardsSet(
        uint256 rewardPerBlock,
        uint256 firstBlockWithReward,
        uint256 lastBlockWithReward
    );
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Recovered(address token, uint256 amount);

    constructor(IERC20 _rewardsToken, IERC20 _stakingToken) {
        rewardsToken = _rewardsToken;
        stakingToken = _stakingToken;
    }

    function blocksWithRewardsPassed() public view returns (uint256) {
        uint256 from = Math.max(lastUpdateBlock, firstBlockWithReward);
        uint256 to = Math.min(block.number, lastBlockWithReward);

        if (from > to) {
            return 0;
        }

        return to.sub(from);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 accumulatedReward =
            blocksWithRewardsPassed().mul(rewardPerBlock).mul(1e18).div(
                totalStaked
            );
        return rewardPerTokenStored.add(accumulatedReward);
    }

    function earned(address _account) public view returns (uint256) {
        uint256 rewardsDifference =
            rewardPerToken().sub(userRewardPerTokenPaid[_account]);
        uint256 newlyAccumulated =
            staked[_account].mul(rewardsDifference).div(1e18);
        return rewards[_account].add(newlyAccumulated);
    }

    function stake(uint256 _amount)
        external
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        require(_amount > 0, "Amount should be greater then 0");
        totalStaked = totalStaked.add(_amount);
        staked[msg.sender] = staked[msg.sender].add(_amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0, "Amount should be greater then 0");
        totalStaked = totalStaked.sub(_amount);
        staked[msg.sender] = staked[msg.sender].sub(_amount);
        stakingToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(staked[msg.sender]);
        getReward();
    }

    function setRewards(
        uint256 _rewardPerBlock,
        uint256 _startingBlock,
        uint256 _blocksAmount
    ) external onlyOwner updateReward(address(0)) {
        rewardPerBlock = _rewardPerBlock;
        firstBlockWithReward = _startingBlock;
        lastBlockWithReward = firstBlockWithReward.add(_blocksAmount);

        emit RewardsSet(
            _rewardPerBlock,
            firstBlockWithReward,
            lastBlockWithReward
        );
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        require(
            tokenAddress != address(stakingToken),
            "Cannot withdraw the staking token"
        );
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
}