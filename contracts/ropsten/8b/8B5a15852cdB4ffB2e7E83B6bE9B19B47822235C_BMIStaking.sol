// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IContractsRegistry.sol";
import "./interfaces/IBMIStaking.sol";
import "./interfaces/tokens/ISTKBMIToken.sol";
import "./interfaces/ILiquidityMining.sol";

import "./tokens/erc20permit-upgradable/IERC20PermitUpgradeable.sol";

import "./abstract/AbstractDependant.sol";

import "./Globals.sol";

contract BMIStaking is IBMIStaking, OwnableUpgradeable, AbstractDependant {
	using SafeMath for uint256;

	IERC20 public bmiToken;
	ISTKBMIToken public override stkBMIToken;
	uint256 public lastUpdateBlock;
	uint256 public rewardPerBlock;
	uint256 public totalPool;

	/***************** PROXY ALERT *****************/
	/******* DO NOT MODIFY THE STORAGE ABOVE *******/

	ILiquidityMining public liquidityMining;
	address public bmiDaiStakingAddress;
	address public liquidityMiningStakingAddress;
	
	mapping(address => uint256) public withdrawCoolDownTime;

	uint256 internal constant WITHDRAWING_LOCKUP_DURATION = 1 days; // 60 days
	uint256 internal constant WITHDRAWING_COOLDOWN_DURATION = 300; // 10 days
	uint256 internal constant WITHDRAW_PHASE_DURATION = 120; // 2 days

	modifier updateRewardPool() {
		if (totalPool == 0) {
			lastUpdateBlock = block.number;
		}
		
		totalPool = totalPool.add(_calculateReward());
		lastUpdateBlock = block.number;
		_;
	}

	modifier onlyStaking() {
		require (_msgSender() == bmiDaiStakingAddress || _msgSender() == liquidityMiningStakingAddress, 
			"BMIStaking: Not a staking contract");
		_;
	}

	function __BMIStaking_init(uint256 _rewardPerBlock)
		external
		initializer
	{
		__Ownable_init();

		lastUpdateBlock = block.number;
		rewardPerBlock = _rewardPerBlock;		
	}	

	function setDependencies(IContractsRegistry _contractsRegistry) external override onlyInjectorOrZero {
		bmiToken = IERC20(_contractsRegistry.getBMIContract());
		stkBMIToken = ISTKBMIToken(_contractsRegistry.getSTKBMIContract());
		liquidityMining = ILiquidityMining(_contractsRegistry.getLiquidityMiningContract());	
		bmiDaiStakingAddress = _contractsRegistry.getBMIDAIStakingContract();
		liquidityMiningStakingAddress = _contractsRegistry.getLiquidityMiningStakingContract();		
	}

	function stakeWithPermit(uint256 _amountBMI, uint8 _v, bytes32 _r, bytes32 _s) external override {
		IERC20PermitUpgradeable(address(bmiToken)).permit(
			_msgSender(),
			address(this),
			_amountBMI,
			MAX_INT,
			_v,
			_r,
			_s
		);

		bmiToken.transferFrom(_msgSender(), address(this), _amountBMI);
		_stake(_msgSender(), _amountBMI);
	}

	function stakeFor(address _user, uint256 _amountBMI) external override onlyStaking updateRewardPool {
		require(_amountBMI > 0, "BMIStaking: can't stake 0 tokens");

		_stake(_user, _amountBMI);
	}

	function stake(uint256 _amountBMI) external override updateRewardPool {
		require(_amountBMI > 0, "BMIStaking: can't stake 0 tokens");

		bmiToken.transferFrom(_msgSender(), address(this), _amountBMI);
		_stake(_msgSender(), _amountBMI);
	}

	// It is unlocked after 60 days
	function isBMIRewardUnlocked() public view returns(bool) {
		uint256 liquidityMiningStartTime = liquidityMining.startLiquidityMiningTime();

		return liquidityMiningStartTime == 0 || 
			liquidityMiningStartTime.add(WITHDRAWING_LOCKUP_DURATION) > block.timestamp ?
			false :
			true;
	}

	// There is a second withdrawal phase of 48 hours to actually receive the rewards. 
	// If a user misses this period, in order to withdraw he has to wait for 10 days again.
	function whenCanWithdrawBMIReward(address _address) public view returns(uint256) {		
		return withdrawCoolDownTime[_address].add(WITHDRAW_PHASE_DURATION) >= block.timestamp ?
			withdrawCoolDownTime[_address] :
			0;
	}	

	/*
	* Before a withdraw, it is needed to wait 60 days after LiquidityMining started.
	* And after 60 days, user can request to withdraw and wait 10 days.
	* After 10 days, user can withdraw, but user has 48hs to withdraw. After 48hs,
	* user will need to request to withdraw again and wait for more 10 days before
	* being able to withdraw.
	*/
	function unlockTokensToWithdraw() external {
		require(stkBMIToken.balanceOf(_msgSender()) > 0, "BMIStaking: not enough stkBMI tokens to unlock");
		require(isBMIRewardUnlocked(), "BMIStaking: lock up duration didnt finish");

		if (whenCanWithdrawBMIReward(_msgSender()) == 0) {
			withdrawCoolDownTime[_msgSender()] = block.timestamp.add(WITHDRAWING_COOLDOWN_DURATION);
		}
	}

	function withdraw(uint256 _amountStkBMI) external override updateRewardPool {
		require(_amountStkBMI > 0, "BMIStaking: can't withdraw zero tokens");
		require(stkBMIToken.balanceOf(_msgSender()) >= _amountStkBMI,
			"BMIStaking: not enough stkBMI tokens to withdraw");
		require(whenCanWithdrawBMIReward(_msgSender()) != 0,
			"BMIStaking: unlock period didn't start yet or expired");		
		require(whenCanWithdrawBMIReward(_msgSender()) <= block.timestamp,
			"BMIStaking: cooldown period not reached");
		require(whenCanWithdrawBMIReward(_msgSender()).add(WITHDRAW_PHASE_DURATION) >= block.timestamp,
			"BMIStaking: 48hs after cooldown expired");

		uint256 amountBMI = _convertToBMI(_amountStkBMI);
		stkBMIToken.burn(_msgSender(), _amountStkBMI);

		totalPool = totalPool.sub(amountBMI);

		require(bmiToken.balanceOf(address(this)) >= amountBMI, "BMIStaking: failed to transfer BMI tokens");
		
		bmiToken.transfer(_msgSender(), amountBMI);

		emit WithdrawnBMI(amountBMI, _amountStkBMI, _msgSender());		
	}

	function addToPool(uint256 _amount) external override onlyStaking updateRewardPool {
		totalPool = totalPool.add(_amount);
	}

	function stakingReward(uint256 _amount) external view override returns (uint256) {
		return _convertToBMI(_amount);
	}

	function getStakedBMI(address _address) external view override returns (uint256) {
		uint256 balance = stkBMIToken.balanceOf(_address);
		return balance > 0 ? _convertToBMI(balance) : 0;
	}

	function setRewardPerBlock(uint256 _amount) external override onlyOwner updateRewardPool {
		rewardPerBlock = _amount;
	}

	function revokeUnusedRewardPool() external override onlyOwner updateRewardPool {
		uint256 contractBalance = bmiToken.balanceOf(address(this));

		require(contractBalance > totalPool, "BMIStaking: There are no unused tokens to revoke");

		uint256 unusedTokens = contractBalance.sub(totalPool);

		bmiToken.transfer(_msgSender(), unusedTokens);
		emit UnusedRewardPoolRevoked(_msgSender(), unusedTokens);
	}

	function _stake(address _staker, uint256 _amountBMI) internal {
		uint256 amountStkBMI = _convertToStkBMI(_amountBMI);
		stkBMIToken.mint(_staker, amountStkBMI);

		totalPool = totalPool.add(_amountBMI);

		emit StakedBMI(_amountBMI, amountStkBMI, _staker);
	}

	function _convertToStkBMI(uint256 _amount) internal view returns (uint256) {
		uint256 TSstkBMIToken = stkBMIToken.totalSupply();
		uint256 stakingPool = totalPool.add(_calculateReward());

		if (stakingPool > 0 && TSstkBMIToken > 0) {
			_amount = TSstkBMIToken.mul(_amount).div(stakingPool);
		}

		return _amount;
	}

	function _convertToBMI(uint256 _amount) internal view returns (uint256) {
		uint256 TSstkBMIToken = stkBMIToken.totalSupply();
		uint256 stakingPool = totalPool.add(_calculateReward());

		return TSstkBMIToken > 0 ? stakingPool.mul(_amount).div(TSstkBMIToken) : 0;
	}

	function _calculateReward() internal view returns (uint256) {
		uint256 blocksPassed = block.number.sub(lastUpdateBlock);
		return rewardPerBlock.mul(blocksPassed);
	}
}