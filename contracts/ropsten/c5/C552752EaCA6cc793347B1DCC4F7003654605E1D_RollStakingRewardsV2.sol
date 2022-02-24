// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "./openzeppelin/utils/ReentrancyGuard.sol";
import "./openzeppelin/math/Math.sol";
import "./openzeppelin/token/ERC20/IERC20.sol";
import "./openzeppelin/math/SafeMath.sol";
import "./openzeppelin/utils/Address.sol";
import "./openzeppelin/token/ERC20/SafeERC20.sol";

import "./RollRewardsDistributionRecipient.sol";
import "./TokenWrapper.sol";

contract RollStakingRewardsV2 is
	RollRewardsDistributionRecipient,
	TokenWrapper,
	ReentrancyGuard
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	/* ========== STATE VARIABLES ========== */

	struct TokenRewardData {
		uint256 rewardRate;
		uint256 rewardPerTokenStored;
	}

	address[] public rewardTokensAddresses;
	mapping(address => TokenRewardData) public rewardTokens;
	mapping(address => mapping(address => uint256))
		public userRewardPerTokenPaid;
	mapping(address => mapping(address => uint256)) public rewards;

	/* ========== GLOBAL STATE VARIABLES ==========  */

	uint256 public periodStart;
	uint256 public periodFinish;
	uint256 public rewardsDuration;

	uint256 public lastUpdateTime;
	uint256 public immutable tokenDecimals;

	/* ========== CONSTRUCTOR ========== */

	constructor(
		address _owner,
		address _rewardsDistribution,
		address[] memory _rewardTokens,
		address _stakingToken,
		address _registry
	) public RollOwned(_owner, _registry) {
		for (uint256 i = 0; i < _rewardTokens.length; i++) {
			rewardTokensAddresses.push(_rewardTokens[i]);
			rewardTokens[_rewardTokens[i]] = TokenRewardData(0, 0);
		}
		token = IERC20(_stakingToken);
		tokenDecimals = token.decimals();
		rewardsDistribution = _rewardsDistribution;
	}

	/* ========== VIEWS ========== */

	function lastTimeRewardApplicable() public view returns (uint256) {
		uint256 n = Math.min(block.timestamp, periodFinish);
		return Math.max(n, periodStart);
	}

	function isValidRewardToken(address _token) public view returns (bool) {
		for (uint256 i = 0; i < rewardTokensAddresses.length; i++)
			if (_token == address(rewardTokensAddresses[i])) return true;
		return false;
	}

	function rewardPerToken(address _token) public view returns (uint256) {
		TokenRewardData storage data = rewardTokens[_token];
		if (_totalSupply == 0 || block.timestamp < periodStart) {
			return data.rewardPerTokenStored;
		}

		return
			data.rewardPerTokenStored.add(
				lastTimeRewardApplicable()
					.sub(lastUpdateTime)
					.mul(data.rewardRate)
					.mul(10**tokenDecimals)
					.div(totalSupply())
			);
	}

	function earned(address _account, address _token)
		public
		view
		returns (uint256)
	{
		return
			balanceOf(_account)
				.mul(
				rewardPerToken(_token).sub(
					userRewardPerTokenPaid[_token][_account]
				)
			)
				.div(10**tokenDecimals)
				.add(rewards[_token][_account]);
	}

	function getRewardForDuration(address _token)
		external
		view
		returns (uint256)
	{
		TokenRewardData storage data = rewardTokens[_token];
		return data.rewardRate.mul(rewardsDuration);
	}

	/* ========== MUTATIVE FUNCTIONS ========== */
	function preCampaign() public onlyRewardsDistribution {
		periodStart = 0;
		periodFinish = 0;
		rewardsDuration = 0;
		lastUpdateTime = 0;
	}

	function postCampaign()
		public
		onlyRewardsDistribution
		nonReentrant
		notPaused
		updateReward(msg.sender)
	{}

	function stake(uint256 amount)
		public
		override
		nonReentrant
		notPaused
		updateReward(msg.sender)
	{
		require(amount > 0, "Cannot stake 0");
		super.stake(amount);
		emit Staked(msg.sender, amount);
	}

	function withdraw(uint256 amount)
		public
		override
		nonReentrant
		updateReward(msg.sender)
	{
		require(amount > 0, "Cannot withdraw 0");
		super.withdraw(amount);
		emit Withdrawn(msg.sender, amount);
	}

	function getReward() public nonReentrant updateReward(msg.sender) {
		for (uint256 i = 0; i < rewardTokensAddresses.length; i++) {
			uint256 reward =
				rewards[address(rewardTokensAddresses[i])][msg.sender];
			if (reward > 0) {
				rewards[address(rewardTokensAddresses[i])][msg.sender] = 0;
				IERC20(rewardTokensAddresses[i]).safeTransfer(
					msg.sender,
					reward
				);
				emit RewardPaid(
					msg.sender,
					address(rewardTokensAddresses[i]),
					reward
				);
			}
		}
	}

	function exit() external {
		withdraw(_balances[msg.sender]);
		getReward();
	}

	/* ========== RESTRICTED FUNCTIONS ========== */

	/* issues with adding multiple tokens
	 * Either we leave them and there will be wasted gas for expired rewards or
	 * we remove a token from the array and prevent anyone from claiming if they forgot to do so
	 * An announcement may be given a week prior from removing a secondary reward token.
	 * this would keep calls as efficient as possible.
	 */
	function notifyRewardAmount(
		uint256[] calldata _rewards,
		address[] calldata _tokens
	) external override onlyRewardsDistribution updateReward(address(0)) {
		require(
			_rewards.length == _tokens.length &&
				rewardTokensAddresses.length == _tokens.length,
			"RollStakingRewards: Amount of rewards not matching reward token count."
		);
		for (uint256 i = 0; i < _tokens.length; i++) {
			TokenRewardData storage data = rewardTokens[_tokens[i]];
			if (block.timestamp >= periodFinish) {
				data.rewardRate = _rewards[i].div(rewardsDuration);
			} else {
				uint256 remaining = periodFinish.sub(block.timestamp);
				if (block.timestamp < periodStart) {
					remaining = periodFinish.sub(periodStart);
				}
				uint256 leftover = remaining.mul(data.rewardRate);
				data.rewardRate = _rewards[i].add(leftover).div(
					rewardsDuration
				);
			}
			uint256 balance = IERC20(_tokens[i]).balanceOf(address(this));
			require(
				data.rewardRate <= balance.div(rewardsDuration),
				"RollStakingRewards: Provided reward too high"
			);
			emit RewardAdded(_rewards[i], _tokens[i]);
		}
		lastUpdateTime = block.timestamp;
		periodFinish = periodStart.add(rewardsDuration);
	}

	function setRewardsDuration(uint256 _periodStart, uint256 _rewardsDuration)
		external
		onlyOwner
	{
		require(
			block.timestamp > periodFinish,
			"RollStakingRewards: Previous rewards period must be complete before changing the duration for the new period"
		);
		require(
			block.timestamp < _periodStart || _periodStart == 0,
			"RollStakingRewards: Start must be a future date"
		);
		if (_periodStart == 0) {
			periodStart = block.timestamp;
		} else {
			periodStart = _periodStart;
		}
		rewardsDuration = _rewardsDuration;
		emit RewardsUpdated(periodStart, rewardsDuration);
	}

	/* ========== MODIFIERS ========== */

	modifier updateReward(address _account) {
		for (uint256 i = 0; i < rewardTokensAddresses.length; i++) {
			TokenRewardData storage data =
				rewardTokens[rewardTokensAddresses[i]];
			data.rewardPerTokenStored = rewardPerToken(
				rewardTokensAddresses[i]
			);
		}
		lastUpdateTime = lastTimeRewardApplicable();
		for (uint256 i = 0; i < rewardTokensAddresses.length; i++) {
			TokenRewardData storage data =
				rewardTokens[rewardTokensAddresses[i]];
			if (_account != address(0)) {
				rewards[rewardTokensAddresses[i]][_account] = earned(
					_account,
					rewardTokensAddresses[i]
				);
				userRewardPerTokenPaid[rewardTokensAddresses[i]][
					_account
				] = data.rewardPerTokenStored;
			}
		}
		_;
	}

	event RewardAdded(uint256 reward, address indexed token);
	event Staked(address indexed user, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event RewardPaid(
		address indexed user,
		address indexed token,
		uint256 reward
	);
	event RewardsUpdated(uint256 newStart, uint256 newDuration);
	event Recovered(address token, uint256 amount);
}