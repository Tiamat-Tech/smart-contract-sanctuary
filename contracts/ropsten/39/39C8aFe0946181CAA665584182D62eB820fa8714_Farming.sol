// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IReserve.sol";

contract Farming is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 entryFarmRound;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 poolStartTime; // timestamp when the owner add a farm
        uint256 globalRoundId; // global round id at the moment pool is created
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardRound; // Last block number that MONEY Tokens distribution occurs.
        uint16 depositFeeBP; // Deposit fee in basis points
        uint256[] cumulativeMoneyPerShare;
        uint256[] deposits;
    }

    // The MONEY TOKEN!
    address public money;
    // Deposit Fee address
    address public feeAddress;
    // Reserve address
    address public reserve;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    uint256 public availableRewards;
    uint256 public constant REWARD_PRECISION = 10**12;

    //round id to reward array
    uint256[] public rewards;
    uint256 public globalRoundId;

    //only after this time, rewards will be fetched and ditributed to the users from last date
    uint256 public reserveDistributionSchedule = 30 days;
    uint256 public lastReserveDistributionTimestamp;
    uint256 public depositPeriod = 24 hours;

    event NewPool(IERC20 _lpToken, uint256 _allocPoint, uint16 _depositFeeBP);
    event UpdatePool(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event UpdatedReserveDistributionSchedule(
        uint256 _reserveDistributionSchedule
    );
    event SetReserveAddress(address _reserve);

    constructor(
        address _money,
        address _feeAddress,
        address _reserve
    ) public {
        require(
            _money != address(0),
            "Farming:constructor:: ERR_ZERO_ADDRESS_MONEY"
        );
        require(
            _feeAddress != address(0),
            "Farming:constructor:: ERR_ZERO_ADDRESS_FEE_ADDRESS"
        );
        require(
            _reserve != address(0),
            "Farming:constructor:: ERR_ZERO_ADDRESS_RESERVE"
        );

        money = _money;
        feeAddress = _feeAddress;
        reserve = _reserve;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP
    ) public onlyOwner {
        require(
            _depositFeeBP <= 10000,
            "Farming:add:: INVALID_FEE_BASIS_POINTS"
        );

        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        PoolInfo memory newPool;

        newPool.lpToken = _lpToken;
        newPool.allocPoint = _allocPoint;
        newPool.poolStartTime = block.number;
        newPool.lastRewardRound = 0;
        newPool.depositFeeBP = _depositFeeBP;
        newPool.globalRoundId = globalRoundId;
        poolInfo.push(newPool);

        emit NewPool(_lpToken, _allocPoint, _depositFeeBP);
    }

    // Update the given pool's MONEY allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP
    ) public onlyOwner {
        require(
            _depositFeeBP <= 10000,
            "Farming:set:: INVALID_FEE_BASIS_POINTS"
        );

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;

        emit UpdatePool(_pid, _allocPoint, _depositFeeBP);
    }

    function getRoundId(uint256 _pid)
        internal
        view
        returns (uint256 depositForRound)
    {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 timeDiff = block.timestamp.sub(pool.poolStartTime);
        depositForRound = timeDiff.div(reserveDistributionSchedule);

        if (timeDiff < depositPeriod) {
            depositForRound = 1;
        } else if (depositForRound == 0) {
            depositForRound = 2;
        }
    }

    function pendingMoney(uint256 _pid, address _user)
        internal
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];

        uint256 start = user.entryFarmRound;

        uint256 currentRound = getRoundId(_pid);
        uint256 end = currentRound == 0 ? 1 : currentRound.sub(1);

        if (start != 0) start = start.sub(1);

        uint256 totalRewardPerShare;

        if (start == end) {
            totalRewardPerShare = pool.cumulativeMoneyPerShare[start];
        } else {
            totalRewardPerShare = pool.cumulativeMoneyPerShare[end].sub(
                pool.cumulativeMoneyPerShare[start]
            );
        }

        pending = user.amount.mul(totalRewardPerShare).div(REWARD_PRECISION);
    }

    // Deposit LP tokens to MoneyFarm for MONEY allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_amount != 0, "Farming:deposit:: INVALID_AMOUNT");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            address(pool.lpToken) != address(0),
            "Farming:deposit:: CANNOT_FARM_THIS_TOKEN"
        );

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        uint256 farmAmount = _amount;
        uint256 currentRound = getRoundId(_pid);
        if (pool.deposits.length < currentRound - 1) {
            //to initialise 0th round
            if (pool.deposits.length == 0) pool.deposits.push(0);
            pool.deposits.push(_amount);
        } else {
            pool.deposits[currentRound] = pool.deposits[currentRound].add(
                _amount
            );
        }

        if (pool.depositFeeBP > 0) {
            uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
            pool.lpToken.safeTransfer(feeAddress, depositFee);
            farmAmount = _amount.sub(depositFee);
        }

        if (user.amount != 0) {
            uint256 pendingRewards = pendingMoney(_pid, msg.sender);

            availableRewards = availableRewards.sub(pendingRewards);
            safeMoneyTransfer(msg.sender, pendingRewards);
        }

        user.entryFarmRound = currentRound;
        user.amount = user.amount.add(farmAmount);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MoneyFarm.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "Farming:withdraw:: INVALID_AMOUNT");

        uint256 pendingRewards = pendingMoney(_pid, msg.sender);

        uint256 currentRound = getRoundId(_pid);
        pool.deposits[currentRound] = pool.deposits[currentRound].sub(_amount);

        if (pendingRewards > 0) {
            availableRewards = availableRewards.sub(pendingRewards);
            safeMoneyTransfer(msg.sender, pendingRewards);
        }

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            user.entryFarmRound = getRoundId(_pid);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        pullRewards();
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function pullRewards() internal returns (uint256 rewardAccumulated) {
        require(
            lastReserveDistributionTimestamp.add(reserveDistributionSchedule) <=
                block.timestamp,
            "REWARDS_NOT_BAKED_YET"
        );

        globalRoundId = globalRoundId + 1;
        rewardAccumulated = IReserve(reserve).withdrawRewards();

        rewards[globalRoundId] = rewardAccumulated;
        availableRewards = availableRewards.add(rewardAccumulated);
        lastReserveDistributionTimestamp = block.timestamp;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 lastPoolRoundUpdated = pool.cumulativeMoneyPerShare.length - 1;
        uint256 lastRewardIndex = pool.globalRoundId - 1;
        uint256 totalRounds = globalRoundId - lastRewardIndex + 1;

        for (
            uint256 round = lastPoolRoundUpdated + 1;
            round <= totalRounds + lastPoolRoundUpdated;
            round++
        ) {
            //to initialise 0th round
            if (pool.cumulativeMoneyPerShare.length == 0)
                pool.cumulativeMoneyPerShare.push(0);

            uint256 share = (
                (rewards[lastRewardIndex + round].mul(pool.allocPoint))
                    .div(totalAllocPoint)
                    .mul(REWARD_PRECISION)
                    .div(pool.deposits[round])
            ).add(pool.cumulativeMoneyPerShare[round - 1]);

            pool.cumulativeMoneyPerShare.push(share);
        }

        pool.lastRewardRound = pool.lastRewardRound.add(1);
    }

    // Safe money transfer function, just in case if rounding error causes pool to not have enough MONEY Tokens.
    function safeMoneyTransfer(address _to, uint256 _amount) internal {
        uint256 moneyBal = IERC20(money).balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > moneyBal) {
            transferSuccess = IERC20(money).transfer(_to, moneyBal);
        } else {
            transferSuccess = IERC20(money).transfer(_to, _amount);
        }
        require(transferSuccess, "safeMoneyTransfer: transfer failed");
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setReserveAddress(address _reserveAddress) public onlyOwner {
        reserve = _reserveAddress;
        emit SetReserveAddress(_reserveAddress);
    }

    function updateReserveDistributionSchedule(
        uint256 _reserveDistributionSchedule
    ) external onlyOwner {
        reserveDistributionSchedule = _reserveDistributionSchedule;
        emit UpdatedReserveDistributionSchedule(_reserveDistributionSchedule);
    }
}