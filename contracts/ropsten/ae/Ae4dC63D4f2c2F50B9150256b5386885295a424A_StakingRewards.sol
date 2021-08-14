// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IStakingRewards.sol";

interface IRewardToken {
    function mint(address recipient_, uint256 amount_) external returns (bool);
}

// Stacking is a smart contract for distributing reward Token by asking user to stake the ERC20-based token.
contract StakingRewards is IStakingRewards, Ownable ,ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many Staking tokens the user has provided.
        uint lastBlock;
        address fundedBy; // Funded by who
    }

    // Info of each pool.
    struct PoolInfo {
        address stakeToken; // Address of Staking token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Reward token to distribute per block.
        uint256 lastRewardBlock; // Last block number that token distribution occurs.
        uint256 accRewardPerShare; // Accumulated token per share
        uint totalStakingWeight;
        uint totalStakingAmount;
    }

    // The Reward TOKEN!
    address public rewardToken;

    // Reward tokens created per block.
    uint256 public rewardPerBlock;
    bool public active;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes Staking tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when Reward token released.
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetRewardPerBlock(uint256 indexed rewardPerBlock);
    event ManualMint(address indexed to,uint256 indexed amount);
    event StakingStopped();
    event StackingResumed();
    event PoolCleaned(uint pid);
    address public rewardPool;
    constructor(
        address _rewardToken,
        address _rewardPool,
        uint256 _rewardPerBlock,
        uint256 _startBlock
    ) public {
        totalAllocPoint = 0;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        rewardPool = _rewardPool;
        if(_startBlock > block.number) {
            startBlock = _startBlock;
        } else {
            startBlock = block.number;
        }

        active = true;
    }

    modifier isActive() {
        require(active, "Inactive Staking");
        _;
    }

    function changeRewardPool(address newRewardPool) override public onlyOwner {
        require(newRewardPool !=address (0), "Invalid reward pool address");
        rewardPool = newRewardPool;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) override public onlyOwner {
        rewardPerBlock = _rewardPerBlock;
        emit SetRewardPerBlock(_rewardPerBlock);
    }

    function getRewardSymbol() override public view returns (string memory) {
        return IERC20Metadata(rewardToken).symbol();
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function addPool(
        uint256 _allocPoint,
        address _stakeToken

    ) public override onlyOwner {
        require(_stakeToken != address(0), "add: not stakeToken addr");
        require(!isDuplicatedPool(_stakeToken), "add: stakeToken dup");
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
        stakeToken: _stakeToken,
        allocPoint: _allocPoint,
        lastRewardBlock: lastRewardBlock,
        accRewardPerShare: 0,
        totalStakingWeight: 0,
        totalStakingAmount: 0
        })
        );
    }

    // Update the given pool's reward allocation point. Can only be called by the owner.
    function setPool(
        uint256 _pid,
        uint256 _allocPoint
    ) public override onlyOwner {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function isDuplicatedPool(address _stakeToken) public view returns (bool) {
        uint256 length = poolInfo.length;
        for (uint256 _pid = 0; _pid < length; _pid++) {
            if(poolInfo[_pid].stakeToken == _stakeToken) return true;
        }
        return false;
    }

    function poolLength() external override view returns (uint256) {
        return poolInfo.length;
    }

    function manualMint(address _to, uint256 _amount) public onlyOwner {
        IRewardToken(address(rewardToken)).mint(_to, _amount);
        emit ManualMint(_to,_amount);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _lastRewardBlock, uint256 _currentBlock) public pure returns (uint256) {
        require(_lastRewardBlock <= _currentBlock, "Block range exceeded");
        return _currentBlock.sub(_lastRewardBlock);
    }

    // View function to see pending reward token on frontend.
    function pendingReward(uint256 _pid, address _user) external override view returns (uint256, address) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardTokenPerShare = 0;
        uint256 lpSupply = IERC20(pool.stakeToken).balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint _completeBlocks = block.number.sub(user.lastBlock); //get staking blocks
            uint _stakerWeight = _completeBlocks.mul(user.amount);

            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 _rewardToken = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            uint accRewardPerShare = pool.accRewardPerShare.add(_rewardToken);
            accRewardTokenPerShare = accRewardPerShare.mul(_stakerWeight).div(pool.totalStakingWeight);
        }
        return (accRewardTokenPerShare, pool.stakeToken);
    }


    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools(uint256[] calldata pids) public {
        for (uint256 i = 0; i < pids.length; i++) {
            updatePool(pids[i]);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public override {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = IERC20(pool.stakeToken).balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        if(pool.totalStakingAmount > 0) {
            // update pool weight when it has user(s) staking
            uint _blocks = block.number.sub(pool.lastRewardBlock);
            pool.totalStakingWeight += _blocks.mul(pool.totalStakingAmount);
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 reward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        IERC20(rewardToken).safeTransferFrom(address(rewardPool), address(this), reward);
        pool.accRewardPerShare = pool.accRewardPerShare.add(reward);
        pool.lastRewardBlock = block.number;
    }


    // Deposit Staking tokens to StakingToken for token allocation.
    function deposit(uint256 _pid, uint256 _amount) nonReentrant isActive public override {
        address _for = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_for];
        if (user.fundedBy != address(0)) require(user.fundedBy == msg.sender, "bad sof");
        require(pool.stakeToken != address(0), "deposit: not accept deposit");

        if (user.amount > 0) _harvest(_for, _pid);
        if (user.fundedBy == address(0)) user.fundedBy = msg.sender;
        IERC20(pool.stakeToken).safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.totalStakingAmount = pool.totalStakingAmount.add(_amount);
        user.lastBlock = block.number;
        user.amount = user.amount.add(_amount);
        emit Deposit(msg.sender, _pid, _amount);
        updatePool(_pid);
    }

    // Withdraw Staking tokens from  Stacking Token.
    function withdraw(uint256 _pid, uint256 _amount) nonReentrant public override {
        _withdraw(msg.sender, _pid, _amount);
    }

    function withdrawAll(uint256 _pid) nonReentrant public override {
        _withdraw(msg.sender, _pid, userInfo[_pid][msg.sender].amount);
    }

    function _withdraw(address _for, uint256 _pid, uint256 _amount) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_for];
        require(user.fundedBy == msg.sender, "only funder");
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        _harvest(_for, _pid);
        user.amount = user.amount.sub(_amount);
        pool.totalStakingAmount = pool.totalStakingAmount.sub(_amount);

        if (pool.stakeToken != address(0)) {
            IERC20(pool.stakeToken).safeTransfer(address(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _pid, user.amount);
    }

    // Harvest reward token earn from the pool.
    function harvest(uint256 _pid) public override {
        updatePool(_pid);
        _harvest(msg.sender, _pid);
    }

    function _harvest(address _to, uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_to];
        require(user.amount > 0, "nothing to harvest");
        require(user.lastBlock < block.number, "Not enough time");

        uint _completeBlocks = block.number.sub(user.lastBlock); //get staking blocks
        uint _stakerWeight = _completeBlocks.mul(user.amount);
        uint _reward = pool.accRewardPerShare.mul(_stakerWeight).div(pool.totalStakingWeight);
        pool.accRewardPerShare = pool.accRewardPerShare.sub(_reward);
        pool.totalStakingWeight = pool.totalStakingWeight.sub(_stakerWeight);
        require(_reward <= IERC20(rewardToken).balanceOf(address(this)), "Not enough reward token");
        user.lastBlock = block.number;
        safeTransfer(_to, _reward);
    }


    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        IERC20(pool.stakeToken).safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    // Safe transfer function, just in case if rounding error causes pool to not have enough reward token.
    function safeTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > rewardBalance) {
            IERC20(rewardToken).transfer(_to, rewardBalance);
        } else {
            IERC20(rewardToken).transfer(_to, _amount);
        }
    }


    function stopStaking() override public onlyOwner isActive {
        active = false;
        emit StakingStopped();
    }

    function resumeStaking() override public onlyOwner {
        require(!active, "Staking in process");
        active = true;
        if(startBlock < block.number) {
            startBlock = block.number;
        }
        for(uint i = 0; i < poolInfo.length; i++) {
            // be ware gas limit
            poolInfo[i].lastRewardBlock = startBlock;
        }
        emit StackingResumed();
    }

    function cleanPools(uint[] calldata pids) override public onlyOwner {
        require(!active, "Staking in process");
        for(uint i = 0; i < pids.length; i++) {
            PoolInfo storage pool = poolInfo[pids[i]];
            if(pool.totalStakingAmount == 0 && pool.accRewardPerShare > 0) { // all user withdrew,
                safeTransfer(msg.sender, pool.accRewardPerShare);
                pool.accRewardPerShare = 0;
                pool.lastRewardBlock = block.number;
                pool.totalStakingWeight = 0;
                emit PoolCleaned(pids[i]);
            }
        }

    }
    function cleanAllPools() override public onlyOwner {
        require(!active, "Staking in process");
        bool hasUserStaking = false;
        for(uint i = 0; i < poolInfo.length; i++) {
            PoolInfo storage pool = poolInfo[i];
            if(pool.totalStakingAmount == 0 && pool.accRewardPerShare > 0) { // all user withdrew,
                safeTransfer(msg.sender, pool.accRewardPerShare);
                pool.accRewardPerShare = 0;
                pool.lastRewardBlock = block.number;
                pool.totalStakingWeight = 0;
                emit PoolCleaned(i);
            } else if(pool.totalStakingAmount > 0 && !hasUserStaking) {
                hasUserStaking = true;
            }
        }

        if(!hasUserStaking) {
            safeTransfer(msg.sender, IERC20(rewardToken).balanceOf(address (this)));
        }
    }
    function getBlock() view external returns(uint256){
        return block.number;
    }
}