// SPDX-License-Identifier: UNLICENSED
// SoneMasterFarmer
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISoneToken.sol";

interface IMigratorToSoneSwap {
	// Perform LP token migration from legacy UniswapV2 to SoneSwap.
	// Take the current LP token address and return the new LP token address.
	// Migrator should have full access to the caller's LP token.
	// Return the new LP token address.
	//
	// XXX Migrator must have allowance access to UniswapV2 LP tokens.
	// SoneSwap must mint EXACTLY the same amount of SoneSwap LP tokens or
	// else something bad will happen. Traditional UniswapV2 does not
	// do that so be careful!
	function migrate(IERC20 token) external returns (IERC20);
}

// SoneMasterFarmer is the master of SONE. He can make SONE and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once SONE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract SoneMasterFarmer is Ownable {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	// Info of each user.
	struct UserInfo {
		uint256 amount; // How many LP tokens the user has provided.
		uint256 rewardDebt; // Reward debt. See explanation below.
		uint256 rewardDebtAtBlock; // the last block user stake
		//
		// We do some fancy math here. Basically, any point in time, the amount of SONEs
		// entitled to a user but is pending to be distributed is:
		//
		//   pending reward = (user.amount * pool.accSonePerShare) - user.rewardDebt
		//
		// Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
		//   1. The pool's `accSonePerShare` (and `lastRewardBlock`) gets updated.
		//   2. User receives the pending reward sent to his/her address.
		//   3. User's `amount` gets updated.
		//   4. User's `rewardDebt` gets updated.
	}

	// Info of each pool.
	struct PoolInfo {
		IERC20 lpToken; // Address of LP token contract.
		uint256 allocPoint; // How many allocation points assigned to this pool. SONEs to distribute per block.
		uint256 lastRewardBlock; // Last block number that SONEs distribution occurs.
		uint256 accSonePerShare; // Accumulated SONEs per share, times 1e12. See below.
	}

	// The SONE TOKEN!
	ISoneToken public sone;
	// Dev address.
	address public devaddr;
	// SONE tokens created per block.
	uint256 public REWARD_PER_BLOCK;
	// Bonus multiplier for early SONE makers.
	uint256[] public REWARD_MULTIPLIER = [32, 32, 32, 32, 16, 8, 4, 2, 1];
	uint256[] public HALVING_AT_BLOCK; // init in constructor function
	uint256 public FINISH_BONUS_AT_BLOCK;

	// The block number when SONE mining starts.
	uint256 public START_BLOCK;

	uint256 public constant PERCENT_LOCK_BONUS_REWARD = 75; // lock 75% of bonus reward in 1 year
	uint256 public constant PERCENT_FOR_DEV = 10; // 10% reward for dev

	// The migrator contract. It has a lot of power. Can only be set through governance (owner).
	IMigratorToSoneSwap public migrator;

	// Info of each pool.
	PoolInfo[] public poolInfo;
	mapping(address => uint256) public poolId1; // poolId1 count from 1, subtraction 1 before using with poolInfo
	// Info of each user that stakes LP tokens. pid => user address => info
	mapping(uint256 => mapping(address => UserInfo)) public userInfo;
	// Total allocation points. Must be the sum of all allocation points in all pools.
	uint256 public totalAllocPoint = 0;

	event Add(uint256 allocPoint, address lpToken, bool withUpdate);
	event Set(uint256 indexed pid, uint256 allocPoint, bool withUpdate);
	event SetMigrator(address migrator);
	event Migrate(uint256 indexed pid);
	event UpdatePool(uint256 indexed pid);
	event Dev(address devaddr);

	event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
	event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
	event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
	event SendSoneReward(address indexed user, uint256 indexed pid, uint256 amount, uint256 lockAmount);

	constructor(
		ISoneToken _sone,
		address _devaddr,
		uint256 _rewardPerBlock,
		uint256 _startBlock,
		uint256 _halvingAfterBlock
	) public {
		sone = _sone;
		devaddr = _devaddr;
		REWARD_PER_BLOCK = _rewardPerBlock;
		START_BLOCK = _startBlock;
		for (uint256 i = 0; i < REWARD_MULTIPLIER.length - 1; i++) {
			uint256 halvingAtBlock = _halvingAfterBlock.mul(i + 1).add(_startBlock);
			HALVING_AT_BLOCK.push(halvingAtBlock);
		}
		FINISH_BONUS_AT_BLOCK = _halvingAfterBlock.mul(REWARD_MULTIPLIER.length - 1).add(_startBlock);
		HALVING_AT_BLOCK.push(uint256(-1));
	}

	function poolLength() external view returns (uint256) {
		return poolInfo.length;
	}

	// Add a new lp to the pool. Can only be called by the owner.
	function add(
		uint256 _allocPoint,
		IERC20 _lpToken,
		bool _withUpdate
	) public onlyOwner {
		require(poolId1[address(_lpToken)] == 0, "SoneMasterFarmer::add: lp is already in pool");
		if (_withUpdate) {
			massUpdatePools();
		}
		uint256 lastRewardBlock = block.number > START_BLOCK ? block.number : START_BLOCK;
		totalAllocPoint = totalAllocPoint.add(_allocPoint);
		poolId1[address(_lpToken)] = poolInfo.length + 1;
		poolInfo.push(PoolInfo({lpToken: _lpToken, allocPoint: _allocPoint, lastRewardBlock: lastRewardBlock, accSonePerShare: 0}));
		emit Add(_allocPoint, address(_lpToken), _withUpdate);
	}

	// Update the given pool's SONE allocation point. Can only be called by the owner.
	function set(
		uint256 _pid,
		uint256 _allocPoint,
		bool _withUpdate
	) public onlyOwner {
		if (_withUpdate) {
			massUpdatePools();
		}
		totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
		poolInfo[_pid].allocPoint = _allocPoint;
		emit Set(_pid, _allocPoint, _withUpdate);
	}

	// Set the migrator contract. Can only be called by the owner.
	function setMigrator(IMigratorToSoneSwap _migrator) public onlyOwner {
		migrator = _migrator;
		emit SetMigrator(address(_migrator));
	}

	// Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
	function migrate(uint256 _pid) public {
		require(address(migrator) != address(0), "migrate: no migrator");
		PoolInfo storage pool = poolInfo[_pid];
		IERC20 lpToken = pool.lpToken;
		uint256 bal = lpToken.balanceOf(address(this));
		lpToken.safeApprove(address(migrator), bal);
		IERC20 newLpToken = migrator.migrate(lpToken);
		require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
		pool.lpToken = newLpToken;
		emit Migrate(_pid);
	}

	// Update reward variables for all pools. Be careful of gas spending!
	function massUpdatePools() public {
		uint256 length = poolInfo.length;
		for (uint256 pid = 0; pid < length; ++pid) {
			updatePool(pid);
		}
	}

	// Update reward variables of the given pool to be up-to-date.
	function updatePool(uint256 _pid) public {
		PoolInfo storage pool = poolInfo[_pid];
		if (block.number <= pool.lastRewardBlock) {
			return;
		}
		uint256 lpSupply = pool.lpToken.balanceOf(address(this));
		if (lpSupply == 0) {
			pool.lastRewardBlock = block.number;
			return;
		}
		uint256 soneForDev;
		uint256 soneForFarmer;
		(soneForDev, soneForFarmer) = getPoolReward(pool.lastRewardBlock, block.number, pool.allocPoint);

		if (soneForDev > 0) {
			sone.mint(devaddr, soneForDev);
			// For more simple, I lock reward for dev if mint reward in bonus time
			if (block.number <= FINISH_BONUS_AT_BLOCK) {
				sone.lock(devaddr, soneForDev.mul(PERCENT_LOCK_BONUS_REWARD).div(100));
			}
		}
		sone.mint(address(this), soneForFarmer);
		pool.accSonePerShare = pool.accSonePerShare.add(soneForFarmer.mul(1e12).div(lpSupply));
		pool.lastRewardBlock = block.number;
		emit UpdatePool(_pid);
	}

	// |--------------------------------------|
	// [20, 30, 40, 50, 60, 70, 80, 99999999]
	// Return reward multiplier over the given _from to _to block.
	function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
		uint256 result = 0;
		if (_from < START_BLOCK) return 0;

		for (uint256 i = 0; i < HALVING_AT_BLOCK.length; i++) {
			uint256 endBlock = HALVING_AT_BLOCK[i];

			if (_to <= endBlock) {
				uint256 m = _to.sub(_from).mul(REWARD_MULTIPLIER[i]);
				return result.add(m);
			}

			if (_from < endBlock) {
				uint256 m = endBlock.sub(_from).mul(REWARD_MULTIPLIER[i]);
				_from = endBlock;
				result = result.add(m);
			}
		}

		return result;
	}

	function getPoolReward(
		uint256 _from,
		uint256 _to,
		uint256 _allocPoint
	) public view returns (uint256 forDev, uint256 forFarmer) {
		uint256 multiplier = getMultiplier(_from, _to);
		uint256 amount = multiplier.mul(REWARD_PER_BLOCK).mul(_allocPoint).div(totalAllocPoint);
		uint256 soneCanMint = sone.cap().sub(sone.totalSupply());

		if (soneCanMint < amount) {
			forDev = 0;
			forFarmer = soneCanMint;
		} else {
			if (soneCanMint < amount.mul(PERCENT_FOR_DEV + 100).div(100)) {
				forDev = 0;
				forFarmer = amount;
			} else {
				forDev = amount.mul(PERCENT_FOR_DEV).div(100);
				forFarmer = amount;
			}
		}
	}

	// View function to see pending SONEs on frontend.
	function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][_user];
		uint256 accSonePerShare = pool.accSonePerShare;
		uint256 lpSupply = pool.lpToken.balanceOf(address(this));
		if (block.number > pool.lastRewardBlock && lpSupply > 0) {
			uint256 soneForFarmer;
			(, soneForFarmer) = getPoolReward(pool.lastRewardBlock, block.number, pool.allocPoint);
			accSonePerShare = accSonePerShare.add(soneForFarmer.mul(1e12).div(lpSupply));
		}
		return user.amount.mul(accSonePerShare).div(1e12).sub(user.rewardDebt);
	}

	function claimReward(uint256 _pid) public {
		updatePool(_pid);
		_harvest(_pid);
	}

	// lock 75% of reward if it come from bonus time
	function _harvest(uint256 _pid) internal {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];

		if (user.amount > 0) {
			uint256 pending = user.amount.mul(pool.accSonePerShare).div(1e12).sub(user.rewardDebt);
			uint256 masterBal = sone.balanceOf(address(this));
			uint256 lockAmount = 0;

			if (pending > masterBal) {
				pending = masterBal;
			}

			if (pending > 0) {
				sone.transfer(msg.sender, pending);
				if (user.rewardDebtAtBlock <= FINISH_BONUS_AT_BLOCK) {
					lockAmount = pending.mul(PERCENT_LOCK_BONUS_REWARD).div(100);
					sone.lock(msg.sender, lockAmount);
				}

				user.rewardDebtAtBlock = block.number;
			}

			user.rewardDebt = user.amount.mul(pool.accSonePerShare).div(1e12);
			emit SendSoneReward(msg.sender, _pid, pending, lockAmount);
		}
	}

	// Deposit LP tokens to SoneMasterFarmer for SONE allocation.
	function deposit(uint256 _pid, uint256 _amount) public {
		require(_amount > 0, "SoneMasterFarmer::deposit: amount must be greater than 0");

		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		updatePool(_pid);
		_harvest(_pid);
		pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
		if (user.amount == 0) {
			user.rewardDebtAtBlock = block.number;
		}
		user.amount = user.amount.add(_amount);
		user.rewardDebt = user.amount.mul(pool.accSonePerShare).div(1e12);
		emit Deposit(msg.sender, _pid, _amount);
	}

	// Withdraw LP tokens from SoneMasterFarmer.
	function withdraw(uint256 _pid, uint256 _amount) public {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		require(user.amount >= _amount, "SoneMasterFarmer::withdraw: not good");

		updatePool(_pid);
		_harvest(_pid);

		if (_amount > 0) {
			user.amount = user.amount.sub(_amount);
			pool.lpToken.safeTransfer(address(msg.sender), _amount);
		}
		user.rewardDebt = user.amount.mul(pool.accSonePerShare).div(1e12);
		emit Withdraw(msg.sender, _pid, _amount);
	}

	// Withdraw without caring about rewards. EMERGENCY ONLY.
	function emergencyWithdraw(uint256 _pid) public {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		pool.lpToken.safeTransfer(address(msg.sender), user.amount);
		emit EmergencyWithdraw(msg.sender, _pid, user.amount);
		user.amount = 0;
		user.rewardDebt = 0;
	}

	// Safe sone transfer function, just in case if rounding error causes pool to not have enough SONEs.
	function safeSoneTransfer(address _to, uint256 _amount) internal {
		uint256 soneBal = sone.balanceOf(address(this));
		if (_amount > soneBal) {
			sone.transfer(_to, soneBal);
		} else {
			sone.transfer(_to, _amount);
		}
	}

	// Update dev address by the previous dev.
	function dev(address _devaddr) public {
		require(msg.sender == devaddr, "dev: wut?");
		devaddr = _devaddr;
		emit Dev(_devaddr);
	}

	function getNewRewardPerBlock(uint256 pid1) public view returns (uint256) {
		uint256 multiplier = getMultiplier(block.number - 1, block.number);
		if (pid1 == 0) {
			return multiplier.mul(REWARD_PER_BLOCK);
		} else {
			return multiplier.mul(REWARD_PER_BLOCK).mul(poolInfo[pid1 - 1].allocPoint).div(totalAllocPoint);
		}
	}

	// mint SONE token via MasterFarmer
	function mintSoneToken(address account, uint256 amount) public onlyOwner {
		sone.mint(account, amount);
	}

	// transfer ownership SONE token
	function transferOwnershipSoneToken(address newOwner) public onlyOwner {
		sone.transferOwnership(newOwner);
	}
}