// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
*   Advanced-logic: Pending Reward logic.
*   The formula we use to calculate the pending reward of each user:
*   - Pending Reward = (user.amount * pool.accCENTPerShare) - user.rewardDebt
*
*   Everytime a user deposits or withdraws to the single-token pool. This happens:
*   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
*   2. User receives the pending reward sent to his/her address.
*   3. User's `amount` gets updated.
*   4. User's `rewardDebt` gets updated.
*/

contract SingleStaking is Context, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public dev;
    uint256 public centPerBlock;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;
    uint256 public constant BONUS_MULTIPLIER = 40;
    bool public initialized;

    /**
    * @notice UserInfo Struct with the staking data of each user.
    * @param amount The amount of CENT a user is staking.
    * @param rewardDebt Reward debt.
    */
    struct UserInfo {
        uint256 amount;   
        uint256 rewardDebt;
    }
        
    /**
    * @notice PoolInfo Struct with the staking data of the pool.
    * @param erc20 Address of the staking token.
    * @param allocPoint The amount of allocation points assigned to this pool.
    * @param lastRewardBlock Last block number that CENT distribution occures.
    * @param accTokenPerShare Accumulated Tokens per share, times 1e12.
    */
    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTokenPerShare;
        uint256 totCentStakedInPool;
    }
    
   

    PoolInfo[] public poolInfo;

    mapping(IERC20 => bool) public poolExistence;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    error NotAuthorized();
    error OnlyOnce();
    

    modifier isDev() {
        if (_msgSender() != dev) {
            revert NotAuthorized();
        }
        _;
    }
    modifier notDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "already exists");
        _;
    }

    modifier poolExists(uint256 pid) {
        require(pid < poolInfo.length, "not in list");
        _;
    }

    modifier notInitialized(){
        if (initialized) revert OnlyOnce();
        _;
        initialized = true;
    }

    event StakedToPool(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 centPerBlock);
    event PoolInitialized(uint256 _allocPoint, IERC20 _lpToken, uint256 _totRewardAmount);
    event SentPendingRewards(address indexed user, uint256 amount);

    /**
    * @param _dev Dev address.
    */ 
    constructor(address _dev, uint256 _centPerBlock) {
        dev = _dev;
        centPerBlock = _centPerBlock;
        startBlock = block.timestamp;
    }

    /**
    * @notice receive (fallback function) If Ether is sendt to this contract,
    *         the transaction reverts and returns the funds to the sender.
    */ 
    receive() external payable {
        revert("not payable receive");
    }
    function setStartBlock(uint256 _startBlock) public onlyOwner {
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
    * @notice Initiates a new pool. Can only be called by the owner.
    * @param _allocPoint Amount of CENT being allocated to this pool.
    * @param _lpToken Reward token address.
    * @param _totRewardAmount Amount of tokens to be allocated as Reward.
    * @dev This is executed in order:
    * @dev 1. sets the current block.number as lastRewardBlock.
    * @dev 2. adds the _allocPoint to totalAllocPoint.
    * @dev 3. creates an entry as true for the pool in poolExistence[].
    * @dev 4. creates the PoolInfo struct and pushes it to the poolInfo[].
    * @dev 5. executes a SafeTransferFrom of rewardtokens into this smartcontract.
    */ 
    function initiatePool(uint256 _allocPoint, IERC20 _lpToken, uint256 _totRewardAmount) 
        external
        onlyOwner
        notDuplicated(_lpToken)
        notInitialized
    {
        IERC20 lpToken = _lpToken;
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accTokenPerShare: 0,
            totCentStakedInPool: 0
        }));

        require(_transferFrom(address(lpToken), address(_msgSender()), address(this), _totRewardAmount));
        initialized = true;
        emit PoolInitialized(_allocPoint, _lpToken, _totRewardAmount);
    }   

    /**
    * @notice Update the given pool's CENT allocation amount.
    * @param _pid Pool id.
    * @param _newAllocPoint New amount to allocate to the pool. Will replace existing alloc.
    * @dev  Can only be called by the owner.
    */ 
    function updateAllocation(uint256 _pid, uint256 _newAllocPoint)
        internal 
        onlyOwner 
        poolExists(_pid) 
    {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_newAllocPoint);
        poolInfo[_pid].allocPoint = _newAllocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) internal pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending Cent´s on frontend.
    function pendingCent(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 centReward = multiplier.mul(centPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(centReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo[0];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 centReward = 
            multiplier.mul(centPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        
        pool.lpToken.safeTransfer(address(dev), centReward.div(10));

        pool.accTokenPerShare = pool.accTokenPerShare.add(centReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    /** 
    * @notice Stake Cent tokens to earn rewards.
    * @param _amount amount of tokens to stake.
    */
    function addStake(uint256 _amount) public nonReentrant poolExists(0) {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_msgSender()];
        updatePool();
        
        if (user.amount > 0) {
            uint256 pending = user.amount
                .mul(pool.accTokenPerShare)
                    .div(1e12)
                        .sub(user.rewardDebt);
            if(pending > 0) {
                _transferFrom(address(pool.lpToken), address(_msgSender()), address(this), pending);
            }
        }
        if(_amount > 0) {
            user.amount = user.amount.add(_amount);
            require(_transferFrom(address(pool.lpToken), address(_msgSender()), address(this), _amount));
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        pool.totCentStakedInPool = pool.totCentStakedInPool.add(_amount);
        emit StakedToPool(_msgSender(), _amount);
    }

    // Withdraw LP tokens from Staking contract.
    function withdrawStake(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_msgSender()];
        require(user.amount >= _amount);
        updatePool();
        
        uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            pool.lpToken.safeTransfer(_msgSender(), pending);
            emit SentPendingRewards(_msgSender(), pending);
        }
        
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(_msgSender()), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(_msgSender(), _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_msgSender()];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(_msgSender()), amount);
        assert(user.amount == 0 && user.rewardDebt == 0);
        emit EmergencyWithdraw(_msgSender(), amount);
    }

    function _transferFrom(address _token, address _from, address _to, uint256 _amount) internal returns(bool) {
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
        return true;
    }

    /**
    * @notice Update to a new dev address by the previous dev address.
    * @param _dev New dev address.
    * @dev  protected by modifier dev.
    */
    function setDevAddress(address _dev) public isDev {
        dev = _dev;
    }

    
    /**
    * @notice Update the emission rate of all pools..
    * @param _centPerBlock new amount to reward per block.
    * @dev  protected by modifier onlyOwner.
    */
    function updateEmissionRate(uint256 _centPerBlock) public onlyOwner {
        updatePool();
        centPerBlock = _centPerBlock;
        
        emit UpdateEmissionRate(_msgSender(), centPerBlock);
    }
}