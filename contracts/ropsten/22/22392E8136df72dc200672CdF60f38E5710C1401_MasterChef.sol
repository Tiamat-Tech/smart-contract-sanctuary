pragma solidity 0.6.7;

import "./lib/enumerableSet.sol";
import "./lib/safe-math.sol";
import "./lib/erc20.sol";
import "./lib/ownable.sol";
import "./interfaces/strategy.sol";
import "./pickle-token.sol";
import "hardhat/console.sol";

// MasterChef was the master of pickle. He now governs over PICKLES. He can make Pickles and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once PICKLES is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens shares the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of PICKLEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.shares * pool.accPicklePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPicklePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. PICKLEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that PICKLEs distribution occurs.
        uint256 accPicklePerShare; // Accumulated PICKLEs per share, times 1e12. See below.
        address strategy;
        uint256 totalShares;
    }

    // The PICKLE TOKEN!
    PickleToken public pickle;
    // Dev fund (10%, initially)
    uint256 public devFundDivRate = 10;
    // Dev address.
    address public devaddr;
    // Treasure address.
    address public treasury;
    // Block number when bonus PICKLE period ends.
    uint256 public bonusEndBlock;
    // PICKLE tokens created per block.
    uint256 public picklePerBlock;
    // Bonus muliplier for early pickle makers.
    uint256 public constant BONUS_MULTIPLIER = 10;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when PICKLE mining starts.
    uint256 public startBlock;

    // Events
    event Recovered(address token, uint256 amount);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        PickleToken _pickle,
        address _devaddr,
        address _treasury,
        uint256 _picklePerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        pickle = _pickle;
        devaddr = _devaddr;
        treasury = _treasury;
        picklePerBlock = _picklePerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate,
        address _strategy
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPicklePerShare: 0,
                strategy: _strategy,
                totalShares: 0
            })
        );
    }

    // Update the given pool's PICKLE allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending PICKLEs on frontend.
    function pendingPickle(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPicklePerShare = pool.accPicklePerShare;
        uint256 lpSupply = pool.totalShares;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);

            uint256 pickleReward =
                multiplier.mul(picklePerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accPicklePerShare = accPicklePerShare.add(
                pickleReward.mul(1e12).div(lpSupply)
            );
        }
        return
            user.shares.mul(accPicklePerShare).div(1e12).sub(user.rewardDebt);
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
        uint256 lpSupply = pool.totalShares;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 pickleReward =
            multiplier.mul(picklePerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        pickle.mint(devaddr, pickleReward.div(devFundDivRate));
        pickle.mint(address(this), pickleReward);
        pool.accPicklePerShare = pool.accPicklePerShare.add(
            pickleReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for PICKLE allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);
        if (user.shares > 0) {
            uint256 pending =
                user.shares.mul(pool.accPicklePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safePickleTransfer(msg.sender, pending);
        }

        //
        uint256 _pool = balance(_pid); //get _pid lptoken balance
        if (_amount > 0) {
            uint256 _before = pool.lpToken.balanceOf(pool.strategy);

            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                pool.strategy,
                _amount
            );

            uint256 _after = pool.lpToken.balanceOf(pool.strategy);
            _amount = _after.sub(_before); // Additional check for deflationary tokens
        }
        uint256 shares = 0;
        if (pool.totalShares == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(pool.totalShares)).div(_pool);
        }

        user.shares = user.shares.add(shares); //add shares instead of amount
        user.rewardDebt = user.shares.mul(pool.accPicklePerShare).div(1e12);
        pool.totalShares = pool.totalShares.add(shares); //add shares in pool

        //}
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _shares) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.shares >= _shares, "withdraw: not good");

        uint256 r = (balance(_pid).mul(_shares)).div(pool.totalShares);

        updatePool(_pid);
        uint256 pending =
            user.shares.mul(pool.accPicklePerShare).div(1e12).sub(
                user.rewardDebt
            );

        safePickleTransfer(msg.sender, pending);
        user.shares = user.shares.sub(_shares);
        user.rewardDebt = user.shares.mul(pool.accPicklePerShare).div(1e12);
        pool.totalShares = pool.totalShares.sub(_shares); //minus shares in pool

        // Check balance
        if (r > 0) {
            uint256 b = pool.lpToken.balanceOf(pool.strategy);
            if (b < r) {
                uint256 _withdraw = r.sub(b);
                IStrategy(pool.strategy).withdraw(_withdraw);
                uint256 _after = pool.lpToken.balanceOf(pool.strategy);
                uint256 _diff = _after.sub(b);
                if (_diff < _withdraw) {
                    r = b.add(_diff);
                }
            }

            pool.lpToken.safeTransferFrom(
                pool.strategy,
                address(msg.sender),
                r
            );
        }

        emit Withdraw(msg.sender, _pid, r);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 r = (balance(_pid).mul(user.shares)).div(pool.totalShares);

        // Check balance
        uint256 b = pool.lpToken.balanceOf(pool.strategy);

        if (b < r) {
            uint256 _withdraw = r.sub(b);
            IStrategy(pool.strategy).withdraw(_withdraw);
            uint256 _after = pool.lpToken.balanceOf(pool.strategy);
            uint256 _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        pool.lpToken.safeTransferFrom(pool.strategy, address(msg.sender), r);
        emit EmergencyWithdraw(msg.sender, _pid, user.shares);
        user.shares = 0;
        user.rewardDebt = 0;
    }

    // Safe pickle transfer function, just in case if rounding error causes pool to not have enough PICKLEs.
    function safePickleTransfer(address _to, uint256 _amount) internal {
        uint256 pickleBal = pickle.balanceOf(address(this));
        if (_amount > pickleBal) {
            pickle.transfer(_to, pickleBal);
        } else {
            pickle.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    // **** Additional functions separate from the original masterchef contract ****
    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setPicklePerBlock(uint256 _picklePerBlock) public onlyOwner {
        require(_picklePerBlock > 0, "!picklePerBlock-0");

        picklePerBlock = _picklePerBlock;
    }

    function setBonusEndBlock(uint256 _bonusEndBlock) public onlyOwner {
        bonusEndBlock = _bonusEndBlock;
    }

    function setDevFundDivRate(uint256 _devFundDivRate) public onlyOwner {
        require(_devFundDivRate > 0, "!devFundDivRate-0");
        devFundDivRate = _devFundDivRate;
    }

    function balance(uint256 _pid) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return IStrategy(pool.strategy).balanceOf();
    }

    function setPoolStragety(uint256 _pid,address _strategy) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        IStrategy(pool.strategy).withdrawAll(_strategy);        
        pool.strategy = _strategy;
    }
}