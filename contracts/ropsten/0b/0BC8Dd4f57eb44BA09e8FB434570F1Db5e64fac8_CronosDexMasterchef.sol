// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./CronosDexToken.sol";

// MasterChef is the master of CRONOS. He can make CronosDex and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CRONOS is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract CronosDexMasterchef is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
      uint256 amount;         // How many LP tokens the user has provided.
      uint256 rewardDebt;     // Reward debt. See explanation below.
      //
      // We do some fancy math here. Basically, any point in time, the amount of CRONOS
      // entitled to a user but is pending to be distributed is:
      //
      //   pending reward = (user.amount * pool.accCronosPerShare) - user.rewardDebt
      //
      // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
      //   1. The pool's `accCronosPerShare` (and `lastRewardSecond`) gets updated.
      //   2. User receives the pending reward sent to his/her address.
      //   3. User's `amount` gets updated.
      //   4. User's `rewardDebt` gets updated.
  }

  // Info of each pool.
  struct PoolInfo {
      IERC20 lpToken;           // Address of LP token contract.
      uint256 allocPoint;       // How many allocation points assigned to this pool. CRONOSs to distribute per second.
      uint256 lastRewardSecond;  // Last timestamp that CRONOSs distribution occurs.
      uint256 accCronosPerShare;   // Accumulated CRONOSs per share, times 1e18. See below.
      uint256 lpSupply;
  }

  // The CRONOS TOKEN!
  CronosDexToken public immutable cronos;
  // Dev address.
  address public devaddr;
  // Treasury address.
  address public treasuryaddr;
  // CRONOS tokens created per second.
  uint256 public CronosPerSecond;

  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint = 0;
  // The timestamp when CronosDex mining starts.
  uint256 public startTime;

  // Maximum CronosPerSecond
  uint256 public MAX_EMISSION_RATE = 2000000000000000000;


  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event SetDevAddress(address indexed user, address indexed newAddress);
  event SetTreasuryAddress(address indexed user, address indexed newAddress);
  event UpdateEmissionRate(address indexed user, uint256 CronosPerSecond);
  event addPool(uint256 indexed pid, address lpToken, uint256 allocPoint);
  event setPool(uint256 indexed pid, address lpToken, uint256 allocPoint);
  event UpdatestartTime(uint256 newstartTime);
  event CronosMintError(bytes reason);

  constructor(
      CronosDexToken _cronos,
      address _devaddr,
      address _treasuryaddr,
      uint256 _CronosPerSecond,
      uint256 _startTime
  ) {
      cronos = _cronos;
      devaddr = _devaddr;
      treasuryaddr = _treasuryaddr;
      CronosPerSecond = _CronosPerSecond;
      startTime = _startTime;
  }

  function poolLength() external view returns (uint256) {
      return poolInfo.length;
  }

  mapping(IERC20 => bool) public poolExistence;
  modifier nonDuplicated(IERC20 _lpToken) {
      require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
      _;
  }

  // Add a new lp to the pool. Can only be called by the owner.
  function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) external onlyOwner nonDuplicated(_lpToken) {
      // valid ERC20 token
      _lpToken.balanceOf(address(this));
      if (_withUpdate) {
          massUpdatePools();
      }
      uint256 lastRewardSecond = block.timestamp > startTime ? block.timestamp : startTime;
      totalAllocPoint = totalAllocPoint.add(_allocPoint);
      poolExistence[_lpToken] = true;
      poolInfo.push(
          PoolInfo({
              lpToken : _lpToken,
              allocPoint : _allocPoint,
              lastRewardSecond : lastRewardSecond,
              accCronosPerShare : 0,
              lpSupply: 0
          })
      );

      emit addPool(poolInfo.length - 1, address(_lpToken), _allocPoint);
  }

  // Update the given pool's CRONOS allocation point and deposit fee. Can only be called by the owner.
  function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
      if (_withUpdate) {
          massUpdatePools();
      }
      totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
      poolInfo[_pid].allocPoint = _allocPoint;

      emit setPool(_pid, address(poolInfo[_pid].lpToken), _allocPoint);
  }

  // Return reward multiplier over the given _from to _to second.
  function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
      return _to.sub(_from);
  }

  // View function to see pending CronosDexs on frontend.
  function pendingCronos(uint256 _pid, address _user) external view returns (uint256) {
      PoolInfo storage pool = poolInfo[_pid];
      UserInfo storage user = userInfo[_pid][_user];
      uint256 accCronosPerShare = pool.accCronosPerShare;
      if (block.timestamp > pool.lastRewardSecond && pool.lpSupply != 0 && totalAllocPoint > 0) {
          uint256 multiplier = getMultiplier(pool.lastRewardSecond, block.timestamp);
          uint256 cronosReward = multiplier.mul(CronosPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
          accCronosPerShare = accCronosPerShare.add(cronosReward.mul(1e18).div(pool.lpSupply));
      }
      return user.amount.mul(accCronosPerShare).div(1e18).sub(user.rewardDebt);
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
      if (block.timestamp <= pool.lastRewardSecond) {
          return;
      }
      if (pool.lpSupply == 0 || pool.allocPoint == 0) {
          pool.lastRewardSecond = block.timestamp;
          return;
      }
      uint256 multiplier = getMultiplier(pool.lastRewardSecond, block.timestamp);
      uint256 cronosReward = multiplier.mul(CronosPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
      
      try cronos.mint(devaddr, cronosReward.div(12)) {
      } catch (bytes memory reason) {
          cronosReward = 0;
          emit CronosMintError(reason);
      }
      
      try cronos.mint(treasuryaddr, cronosReward.div(15)) {
      } catch (bytes memory reason) {
          cronosReward = 0;
          emit CronosMintError(reason);
      }
      
      try cronos.mint(address(this), cronosReward) {
      } catch (bytes memory reason) {
          cronosReward = 0;
          emit CronosMintError(reason);
      }
      
      pool.accCronosPerShare = pool.accCronosPerShare.add(cronosReward.mul(1e18).div(pool.lpSupply));
      pool.lastRewardSecond = block.timestamp;
  }
  
  // Deposit LP tokens to MasterChef for CRONOS allocation.
  function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
      PoolInfo storage pool = poolInfo[_pid];
      UserInfo storage user = userInfo[_pid][msg.sender];
      updatePool(_pid);
      if (user.amount > 0) {
          uint256 pending = user.amount.mul(pool.accCronosPerShare).div(1e18).sub(user.rewardDebt);
          if (pending > 0) {
              safeCronosTransfer(msg.sender, pending);
          }
      }
      if (_amount > 0) {
          uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
          pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
          _amount = pool.lpToken.balanceOf(address(this)) - balanceBefore;
          user.amount = user.amount.add(_amount);
          pool.lpSupply = pool.lpSupply.add(_amount);
      }
      user.rewardDebt = user.amount.mul(pool.accCronosPerShare).div(1e18);
      emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
      PoolInfo storage pool = poolInfo[_pid];
      UserInfo storage user = userInfo[_pid][msg.sender];
      require(user.amount >= _amount, "withdraw: not good");
      updatePool(_pid);
      uint256 pending = user.amount.mul(pool.accCronosPerShare).div(1e18).sub(user.rewardDebt);
      if (pending > 0) {
          safeCronosTransfer(msg.sender, pending);
      }
      if (_amount > 0) {
          user.amount = user.amount.sub(_amount);
          pool.lpToken.safeTransfer(address(msg.sender), _amount);
          pool.lpSupply = pool.lpSupply.sub(_amount);
      }
      user.rewardDebt = user.amount.mul(pool.accCronosPerShare).div(1e18);
      emit Withdraw(msg.sender, _pid, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) external nonReentrant {
      PoolInfo storage pool = poolInfo[_pid];
      UserInfo storage user = userInfo[_pid][msg.sender];
      uint256 amount = user.amount;
      user.amount = 0;
      user.rewardDebt = 0;
      pool.lpToken.safeTransfer(address(msg.sender), amount);

      if (pool.lpSupply >=  amount) {
          pool.lpSupply = pool.lpSupply.sub(amount);
      } else {
          pool.lpSupply = 0;
      }

      emit EmergencyWithdraw(msg.sender, _pid, amount);
  }

  // Safe cronos transfer function, just in case if rounding error causes pool to not have enough CRONOSs.
  function safeCronosTransfer(address _to, uint256 _amount) internal {
      uint256 cronosBal = cronos.balanceOf(address(this));
      bool transferSuccess = false;
      if (_amount > cronosBal) {
          transferSuccess = cronos.transfer(_to, cronosBal);
      } else {
          transferSuccess = cronos.transfer(_to, _amount);
      }
      require(transferSuccess, "safeCronosTransfer: transfer failed");
  }

  // Update dev address.
  function setDevAddress(address _devaddr) external onlyOwner {
      require(_devaddr != address(0), "!nonzero");

      devaddr = _devaddr;
      emit SetDevAddress(msg.sender, _devaddr);
  }

  function setTreasuryAddress(address _treasuryaddr) external onlyOwner{
      require(_treasuryaddr != address(0), "!nonzero");
      treasuryaddr = _treasuryaddr;
      emit SetTreasuryAddress(msg.sender, _treasuryaddr);
  }

  // Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
  function updateEmissionRate(uint256 _CronosPerSecond) external onlyOwner {
      require(_CronosPerSecond <= MAX_EMISSION_RATE, "Too high");
      massUpdatePools();
      CronosPerSecond = _CronosPerSecond;
      emit UpdateEmissionRate(msg.sender, _CronosPerSecond);
  }

  // Only update before start of farm
  function updatestartTime(uint256 _newstartTime) external onlyOwner {
      require(block.timestamp < startTime, "cannot change start time if farm has already started");
      require(block.timestamp < _newstartTime, "cannot set start time in the past");
      uint256 length = poolInfo.length;
      for (uint256 pid = 0; pid < length; ++pid) {
          PoolInfo storage pool = poolInfo[pid];
          pool.lastRewardSecond = _newstartTime;
      }
      startTime = _newstartTime;

      emit UpdatestartTime(startTime);
  }
}