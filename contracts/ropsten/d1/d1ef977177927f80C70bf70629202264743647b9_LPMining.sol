// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract LPMining is Ownable {
	using SafeMath for uint;
	using SafeERC20 for IERC20;

	struct VestingModel {
		uint tokenLockPeriod;
		uint vestingPeriod;
		uint stakingCap;
		uint rewardPerToken;
		uint amountStaked;
	}

	struct UserVesting {
		uint vestingModelId;
		uint amountStaked;
		uint stakeTimestamp;
		bool stakeWithdrawn;
		uint totalRewards;
		uint rewardsHarvested;
	}

	IERC20 public stakingToken;
	IERC20 public rewardToken;
	VestingModel[] public vestingModels;
	mapping(address => UserVesting[]) public userVestings;

	bool public started;

	event Deposit(address indexed _address, uint _amount);
	event Withdraw(address indexed _address, uint _amount);
	event Harvest(address indexed _address, uint _amount);

	constructor(IERC20 _stakingToken, IERC20 _rewardToken) public {
		stakingToken = _stakingToken;
		rewardToken = _rewardToken;

		// _addVestingModel(30 days, 90 days, 5000 ether, 23);
		// _addVestingModel(90 days, 180 days, 2500 ether, 150);
		// _addVestingModel(180 days, 360 days, 1250 ether, 461);

		_addVestingModel(0, 90 days ,5000 ether, 23);
		_addVestingModel(1 days, 180 days,2500 ether, 150);
		_addVestingModel(2 days, 360 days, 1250 ether, 461);
	}

	// ========================================
	//
	// Admin Functions
	//
	// ========================================

	function start() external onlyOwner {
		started = true;

		// Transfer rewards token into contract
		for (uint i = 0; i < vestingModels.length; i++) {
			uint amount = (vestingModels[i].stakingCap).mul(vestingModels[i].rewardPerToken);
			rewardToken.safeTransferFrom(msg.sender, address(this), amount);
		}
	}

	function increaseStakingCap(uint _vestingModelId, uint _stakingCap) external onlyOwner {
		VestingModel storage vestingModel = vestingModels[_vestingModelId];

		require(_stakingCap > vestingModel.stakingCap, "Staking Cap has to be larger");

		// Transfer rewards token into contract
		uint amount = (_stakingCap.sub(vestingModel.stakingCap)).mul(vestingModel.rewardPerToken);
		rewardToken.safeTransferFrom(msg.sender, address(this), amount);

		vestingModel.stakingCap = _stakingCap;
	}

	function _addVestingModel(
		uint _tokenLockPeriod,
		uint _vestingPeriod,
		uint _stakingCap,
		uint _rewardPerToken
	) internal {
		VestingModel memory vestingModel = VestingModel({
			tokenLockPeriod: _tokenLockPeriod,
			vestingPeriod: _vestingPeriod,
			stakingCap: _stakingCap,
			rewardPerToken: _rewardPerToken,
			amountStaked: 0
		});

		vestingModels.push(vestingModel);
	}

	// ========================================
	//
	// Modifier Functions
	//
	// ========================================

	modifier validVestingModel(uint _vestingModelId) {
		require(vestingModels[_vestingModelId].stakingCap > 0, "Invalid vesting model ID");
		_;
	}

	modifier validUserVesting(uint _userVestingId) {
		require(userVestings[msg.sender][_userVestingId].amountStaked > 0, "Invalid user vesting ID");
		_;
	}


	// ========================================
	//
	// Public Functions
	//
	// ========================================

	function deposit(uint _vestingModelId, uint _amount) validVestingModel(_vestingModelId) external {
		require(started, "LP Mining not started");

		stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

		VestingModel storage vestingModel = vestingModels[_vestingModelId];

		require((vestingModel.amountStaked).add(_amount) <= vestingModel.stakingCap, "Exceeded staking cap");

		vestingModel.amountStaked = (vestingModel.amountStaked).add(_amount);

		UserVesting memory userVesting = UserVesting({
			vestingModelId: _vestingModelId,
			amountStaked: _amount,
			stakeTimestamp: block.timestamp,
			stakeWithdrawn: false,
			totalRewards: _amount.mul(vestingModel.rewardPerToken),
			rewardsHarvested: 0
		});

		userVestings[msg.sender].push(userVesting);

		emit Deposit(msg.sender, _amount);
	}

	function withdraw(uint _userVestingId) validUserVesting(_userVestingId) external {
		UserVesting storage userVesting = userVestings[msg.sender][_userVestingId];
		VestingModel storage vestingModel = vestingModels[userVesting.vestingModelId];

		require(!userVesting.stakeWithdrawn, "Stake already withdrawn");

		uint userAmountStaked = userVesting.amountStaked;

		if (block.timestamp >= (userVesting.stakeTimestamp).add(vestingModel.tokenLockPeriod)) {
			// Set stake withdrawn if lock is over
			userVesting.stakeWithdrawn = true;
		} else {
			// Remove entry if lock is not over
			vestingModel.amountStaked = (vestingModel.amountStaked).sub(userAmountStaked);
			delete userVestings[msg.sender][_userVestingId];
		}

		stakingToken.safeTransfer(msg.sender, userAmountStaked);

		emit Withdraw(msg.sender, userAmountStaked);
	}

	function harvest(uint _userVestingId) validUserVesting(_userVestingId) public {
		UserVesting storage userVesting = userVestings[msg.sender][_userVestingId];
		VestingModel memory vestingModel = vestingModels[userVesting.vestingModelId];

		require(block.timestamp >= (userVesting.stakeTimestamp).add(vestingModel.tokenLockPeriod), "Harvest period has not begun");

		uint rewardPerDay = (userVesting.totalRewards).div(vestingModel.vestingPeriod).mul(86400);
		// uint daysElapsed = (block.timestamp).sub(userVesting.stakeTimestamp).div(86400);
		uint daysElapsed = (block.timestamp).sub(userVesting.stakeTimestamp).div(60);

		uint rewardAmount = rewardPerDay.mul(daysElapsed).sub(userVesting.rewardsHarvested);

		if (rewardAmount.add(userVesting.rewardsHarvested) > userVesting.totalRewards) {
			rewardAmount = (userVesting.totalRewards).sub(userVesting.rewardsHarvested);
		}

		if (rewardAmount > 0) {
			userVesting.rewardsHarvested = (userVesting.rewardsHarvested).add(rewardAmount);
			rewardToken.safeTransfer(msg.sender, rewardAmount);

			emit Harvest(msg.sender, rewardAmount);
		}
	}

	function harvestAll() public {
		for(uint i = 0; i < userVestings[msg.sender].length; i++) {
			UserVesting memory userVesting = userVestings[msg.sender][i];
			VestingModel memory vestingModel = vestingModels[userVesting.vestingModelId];

			if (userVesting.amountStaked > 0 && block.timestamp >= (userVesting.stakeTimestamp).add(vestingModel.tokenLockPeriod)) {
				harvest(i);
			}
		}
	}

	// ========================================
	//
	// View Functions
	//
	// ========================================

	function pendingHarvest(address _user, uint _userVestingId) public view returns (uint) {
		UserVesting memory userVesting = userVestings[_user][_userVestingId];
		VestingModel memory vestingModel = vestingModels[userVesting.vestingModelId];

		if (block.timestamp < (userVesting.stakeTimestamp).add(vestingModel.tokenLockPeriod)) {
			return 0;
		}

		uint rewardPerDay = (userVesting.totalRewards).div(vestingModel.vestingPeriod).mul(86400);
		// uint daysElapsed = (block.timestamp).sub(userVesting.stakeTimestamp).div(86400);
		uint daysElapsed = (block.timestamp).sub(userVesting.stakeTimestamp).div(60);

		uint rewardAmount = rewardPerDay.mul(daysElapsed).sub(userVesting.rewardsHarvested);

		if (rewardAmount.add(userVesting.rewardsHarvested) > userVesting.totalRewards) {
			rewardAmount = (userVesting.totalRewards).sub(userVesting.rewardsHarvested);
		}

		return rewardAmount;

	}

	function pendingHarvestAll(address _user) external view returns (uint) {
		uint total = 0;

		for(uint i = 0; i < userVestings[_user].length; i++) {
			total = total.add(pendingHarvest(_user, i));
		}

		return total;
	}

	function getVestingModels() external view returns (VestingModel[] memory) {
		return vestingModels;
	}

	function getUserVestings(address _user) external view returns (UserVesting[] memory) {
		return userVestings[_user];
	}
}