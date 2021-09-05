// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//modified from https://github.com/Uniswap/liquidity-staker/blob/master/contracts/StakingRewards.sol
contract StakingRewards is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    // using IERC20 interface since signature of totalSupply() is the same
    IERC20 public cryptoDateNft;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 30 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    // The number of cryptodates that have to be minted to start the next farming epoch
    uint256 public immutable numberCdToStartNextEpoch; 

    // last total supply of NFTs 
    uint256 public lastTotalSupply;

    // current epoch
    uint256 public epoch = 0;

    uint256 public immutable rewardPerPeriod;
    /* ========== CONSTRUCTOR ========== */

    constructor(uint256 _numberCdToStartNextEpoch,
        uint256 _rewardPerPeriod,
        address _rewardsToken,
        address _stakingToken,
        address _cryptoDateNft
    )  {
        numberCdToStartNextEpoch = _numberCdToStartNextEpoch;
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        cryptoDateNft = IERC20(_cryptoDateNft);
        //init rewards
        rewardPerPeriod = _rewardPerPeriod;
        rewardRate = _rewardPerPeriod.div(rewardsDuration);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);

    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function canExtendRewards() public view returns (bool) {
        // can't extend farming if farming is currently in progress
        if (block.timestamp < periodFinish) {
            return false;
        }

        //can't start the next epoch until threshold is met, which is 
        //formulated as total supply from next epoch + numberCdToStartNextEpoch 
        return cryptoDateNft.totalSupply() >= lastTotalSupply.add(numberCdToStartNextEpoch.mul(epoch.add(1)));

    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant  {
        require(amount > 0, "Cannot stake 0");
        updateReward(msg.sender);
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public nonReentrant  {
        require(amount > 0, "Cannot withdraw 0");
        updateReward(msg.sender);
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
    }

    function getReward() public nonReentrant  {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }
    function extendRewards() public {
        if (canExtendRewards() == false) {
            return;
        }

        updateReward(address(0));
        //push the periodFinish block forward which will allow farming to start again
        periodFinish = block.timestamp + rewardsDuration;
        // set the lastTotalSupply to the total supply now 
        lastTotalSupply = cryptoDateNft.totalSupply();
        lastUpdateTime = block.timestamp;
        epoch = epoch + 1;
    }

    function updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
            //check to see if a new rewards period can be started
            if (canExtendRewards()) {
                extendRewards();
            }
        }

    }

}