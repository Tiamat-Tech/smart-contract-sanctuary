pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



// Staker is the master of staking and reward tokens.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract 
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Staker is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        
        //
        // We do some fancy math here. Basically, any point in time, the amount of rewards
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accStakerPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accStakerPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 stakingToken; // Address of StakingToken.
        IERC20 rewardToken; // Address of rewardToken
        uint256 rewardPerBlock; //reward prt block
        uint256 totalRewardToken; //total Reward Token send to  contract
        uint256 totalRewardTokenGiven; // total Reward Token Given until now
        uint256 startBlock; // reward start block 
        // uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SUSHIs distribution occurs.
        uint256 accStakerPerShare; // Accumulated reward token per share, times 1e12. See below.
    }
    
    // Dev address.
    // address public devaddr;
    // Block number when bonus SUSHI period ends.
    // uint256 public bonusEndBlock;
    // SUSHI tokens created per block.
    // uint256 public sushiPerBlock;
    // Bonus muliplier for early sushi makers.
    // uint256 public constant BONUS_MULTIPLIER = 10;
    
    
    PoolInfo[] public poolInfo;
    // Info of each user that stakes tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    // uint256 public totalAllocPoint = 0;
    
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    // constructor(
        
    // ) public {
       
    // }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new staking and reward tokens to the pool. Can only be called by the owner.
    // XXX DO NOT add the same staking and reward token more than once. Rewards will be messed up if you do.
    function add(
        // uint256 _allocPoint,
        IERC20 _stakingToken,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _totalRewardToken,
        uint256 _startBlock,
        bool _withUpdate
    ) public onlyOwner {
        require(_totalRewardToken != 0, 'please send some reward tokens');
        require(_rewardToken.balanceOf(msg.sender) > 0,"sender dont have reward tokens");

        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > _startBlock ? block.number : _startBlock;
        // totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                stakingToken: _stakingToken,
                rewardToken: _rewardToken,
                rewardPerBlock: _rewardPerBlock,
                totalRewardToken: _totalRewardToken,
                totalRewardTokenGiven: 0,
                startBlock: _startBlock,
                // allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accStakerPerShare: 0
            })
        );

        _rewardToken.safeTransferFrom(msg.sender,address(this), _totalRewardToken);
    }

    // Update the given pool's staking and reward tokens and allocation point. Can only be called by the owner.
    // if pool ihave already reward token, this function will not be executed
    // if pool dont have reward tokens, admin can start new campaign

    function set(
        uint256 _pid,
        uint256 _rewardPerBlock,
        uint256 _totalRewardToken,
        uint256 _startBlock,
        // uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        require(poolInfo[_pid].rewardToken.balanceOf(address(this)) == 0,"campaign already running");
        require(_totalRewardToken != 0, "please send some reward tokens");
        require(poolInfo[_pid].rewardToken.balanceOf(msg.sender) > 0,"sender dont have reward tokens");
        
        if (_withUpdate) {
            massUpdatePools();
        }
        // totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
        //     _allocPoint
        // );
        
        uint256 lastRewardBlock =
            block.number > _startBlock ? block.number : _startBlock;
        PoolInfo storage pool = poolInfo[_pid];

        // pool.allocPoint = _allocPoint;
        pool.rewardPerBlock = _rewardPerBlock;
        pool.totalRewardToken = _totalRewardToken;
        pool.startBlock = _startBlock;
        pool.lastRewardBlock = lastRewardBlock;

        pool.rewardToken.safeTransferFrom(msg.sender,address(this), _totalRewardToken);
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from);


        // if (_to <= bonusEndBlock) {
        //     return _to.sub(_from).mul(BONUS_MULTIPLIER);
        // } else if (_from >= bonusEndBlock) {
        //     return _to.sub(_from);
        // } else {
        //     return
        //         bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
        //             _to.sub(bonusEndBlock)
        //         );
        // }
    }

    // View function to see pending rewardss on frontend.
    
    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accStakerPerShare = pool.accStakerPerShare;
        uint256 stakingTokenSupply = pool.stakingToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && stakingTokenSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 reward =
                multiplier.mul(pool.rewardPerBlock);
                // .mul(pool.allocPoint).div(
                //     totalAllocPoint
                // );
            accStakerPerShare = accStakerPerShare.add(
                reward.mul(1e12).div(stakingTokenSupply)
            );
        }
        return user.amount.mul(accStakerPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
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
        uint256 stakingTokenSupply = pool.stakingToken.balanceOf(address(this));
        if (stakingTokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 reward =
            multiplier.mul(pool.rewardPerBlock);
            // .mul(pool.allocPoint).div(
            //     totalAllocPoint
            // );
            
        //give reward here  

        pool.accStakerPerShare = pool.accStakerPerShare.add(
            reward.mul(1e12).div(stakingTokenSupply)
        );

        pool.lastRewardBlock = block.number;
    }

    // Deposit staking tokens to Staker for pending allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accStakerPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safeRewardTransfer(pool.rewardToken, msg.sender, pending);
        }
        pool.stakingToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accStakerPerShare).div(1e12);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw staking tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accStakerPerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeRewardTransfer(pool.rewardToken, msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accStakerPerShare).div(1e12);
        pool.stakingToken.safeTransfer(address(msg.sender), _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.stakingToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe sushi transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeRewardTransfer(IERC20 rewardToken, address _to, uint256 _amount) internal {
        uint256 rewardTokenBal = rewardToken.balanceOf(address(this));
        if (_amount > rewardTokenBal) {
            rewardToken.transfer(_to, rewardTokenBal);
        } else {
            rewardToken.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    // function dev(address _devaddr) public {
    //     require(msg.sender == devaddr, "dev: wut?");
    //     devaddr = _devaddr;
    // }
}