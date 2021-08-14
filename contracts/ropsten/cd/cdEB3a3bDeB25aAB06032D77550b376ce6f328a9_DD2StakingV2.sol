//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol';

import "./CakeToken.sol";
import "./SyrupBar.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "hardhat/console.sol";

interface MIERC721 is IERC721 {
    function mint(address to, uint256 id) external;
}
// import "@nomiclabs/buidler/console.sol";

interface IMigratorChef {

    function migrate(IBEP20 token) external returns (IBEP20);
}

contract DD2StakingV2 is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    uint256 private _tokenIds;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardCanHarvest;
        uint256 lastDeposit;
        bool mintNFT;

    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. CAKEs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that CAKEs distribution occurs.
        uint256 accCakePerShare; // Accumulated CAKEs per share, times 1e12. See below.
        bool exist;
    }

    // The CAKE TOKEN!
    CakeToken public cake;
    // The SYRUP TOKEN!
    SyrupBar public syrup;
    // Dev address.
    address public devaddr;
    // CAKE tokens created per block.
    uint256 public cakePerBlock;
    // Bonus muliplier for early cake makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when CAKE mining starts.
    uint256 public startBlock;

    address public immutable ERC721;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        CakeToken _cake,
        SyrupBar _syrup,
        address _devaddr,
        uint256 _cakePerBlock,
        uint256 _startBlock,
        address _ERC721
    ) public {
        cake = _cake;
        syrup = _syrup;
        devaddr = _devaddr;
        cakePerBlock = _cakePerBlock;
        startBlock = _startBlock;
        ERC721 = _ERC721;
        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _cake,
            allocPoint: 1000,
            lastRewardBlock: block.timestamp,
            accCakePerShare: 0,
            exist: true
        }));

        totalAllocPoint = 1000;

    }

    modifier existPool(uint256 _pid) {
        if (poolInfo[_pid].exist == true) {
         _;
        }
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.timestamp;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCakePerShare: 0,
            exist: true
        }));
        updateStakingPool();
    }

    // Update the given pool's CAKE allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 0; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            //points = points.div(3);
            totalAllocPoint = points;
            //poolInfo[0].allocPoint = points;
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending CAKEs on frontend.
    function pendingCake(uint256 _pid, address _user) external view existPool(_pid) returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCakePerShare = pool.accCakePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp  > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.timestamp );
            uint256 cakeReward = multiplier.mul(cakePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accCakePerShare = accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCakePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public existPool(_pid) {

        PoolInfo storage pool = poolInfo[_pid];

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.timestamp );

        uint256 cakeReward = multiplier.mul(cakePerBlock).mul(pool.allocPoint).div(totalAllocPoint);

        cake.mint(devaddr, cakeReward.div(10));
        cake.mint(address(syrup), cakeReward);
        pool.accCakePerShare = pool.accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));

            //pool.accCakePerShare + (cakeReward * 10^12/lpSupply)
        pool.lastRewardBlock = block.timestamp;
    }

    function getmul(uint256 _pid) public view returns (uint256)  {

        PoolInfo storage pool = poolInfo[_pid];


        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.timestamp );
        return multiplier;
    }

    function getlpSupply(uint256 _pid) public view returns (uint256)  {

        PoolInfo storage pool = poolInfo[_pid];

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));



        return lpSupply;
    }

    // Deposit LP tokens to MasterChef for CAKE allocation.
    function deposit(uint256 _pid, uint256 _amount) public existPool(_pid) {

        require (_pid != 0, 'deposit CAKE by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                //safeCakeTransfer(msg.sender, pending);
                user.rewardCanHarvest = user.rewardCanHarvest.add(pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        user.mintNFT = true;
        user.lastDeposit = block.timestamp;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public existPool(_pid) {

        require (_pid != 0, 'withdraw CAKE by unstaking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        //NBN
        uint penaltiesRate = 0;
        if (user.lastDeposit + 3 days > block.timestamp) {
            penaltiesRate = 3;
        }

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
//            safeCakeTransfer(msg.sender, pending);
            user.rewardCanHarvest = user.rewardCanHarvest.add(pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount - penaltiesRate.mul(_amount).div(100));
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

        user.lastDeposit = block.timestamp;
        emit Withdraw(msg.sender, _pid, _amount);
    }

//    // Stake CAKE tokens to MasterChef
//    function enterStaking(uint256 _amount) public {
//        PoolInfo storage pool = poolInfo[0];
//        UserInfo storage user = userInfo[0][msg.sender];
//        updatePool(0);
//        if (user.amount > 0) {
//            uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
//            if(pending > 0) {
//                safeCakeTransfer(msg.sender, pending);
//            }
//        }
//        if(_amount > 0) {
//            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
//            user.amount = user.amount.add(_amount);
//        }
//        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
//
//        syrup.mint(msg.sender, _amount);
//        emit Deposit(msg.sender, 0, _amount);
//    }
//
//    // Withdraw CAKE tokens from STAKING.
//    function leaveStaking(uint256 _amount) public {
//        PoolInfo storage pool = poolInfo[0];
//        UserInfo storage user = userInfo[0][msg.sender];
//        require(user.amount >= _amount, "withdraw: not good");
//        updatePool(0);
//        uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
//        if(pending > 0) {
//            safeCakeTransfer(msg.sender, pending);
//        }
//        if(_amount > 0) {
//            user.amount = user.amount.sub(_amount);
//            pool.lpToken.safeTransfer(address(msg.sender), _amount);
//        }
//        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
//
//        syrup.burn(msg.sender, _amount);
//        emit Withdraw(msg.sender, 0, _amount);
//    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe cake transfer function, just in case if rounding error causes pool to not have enough CAKEs.
    function safeCakeTransfer(address _to, uint256 _amount) internal {
        syrup.safeCakeTransfer(_to, _amount);
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    //----------------------------------------- UPDATE------------------------

    function getReward(uint256 _pid) external view returns (uint256) {
//        require(poolInfo[_pid].exists, "PoolInfo does not exist.");
        UserInfo storage user = userInfo[_pid][msg.sender];

        return user.rewardCanHarvest;
    }

    function getStaking(uint256 _pid) external view existPool(_pid) returns (uint256) {
//        require(poolInfo[_pid].exists, "PoolInfo does not exist.");
        UserInfo storage user = userInfo[_pid][msg.sender];

        return user.amount;
    }

    function harvest(uint256 _pid) public existPool(_pid) {
//        require(poolInfo[_pid].exists, "PoolInfo does not exist.");

        UserInfo storage user = userInfo[_pid][msg.sender];

        safeCakeTransfer(msg.sender, user.rewardCanHarvest);
        user.rewardCanHarvest =  0;

        emit Harvest(msg.sender, user.rewardCanHarvest);

    }
    function reCalReward(uint256 _pid) public existPool(_pid) {
//        require(poolInfo[_pid].exists, "PoolInfo does not exist.");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
//                rewardToken.safeTransfer(address(msg.sender), pending);
                user.rewardCanHarvest = user.rewardCanHarvest.add(pending);
            }
        }

        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
    }

    function getD2NFT(uint256 _pid) public existPool(_pid) returns (uint256) {

        UserInfo storage user = userInfo[_pid][msg.sender];

        require (user.lastDeposit + 3 days < block.timestamp, "deposit < 3 day!");
        require (user.mintNFT, "minted!");

        user.mintNFT = false;

        _tokenIds =  _tokenIds.add(1);

        MIERC721(ERC721).mint(msg.sender, _tokenIds);

        return _tokenIds;
    }

}