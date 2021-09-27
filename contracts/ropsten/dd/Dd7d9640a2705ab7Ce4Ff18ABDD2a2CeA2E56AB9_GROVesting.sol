// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../common/Constants.sol";

interface IMintable {
    function mint(address _receiver, uint256 _amount) external;
}

interface IMigrator {
    function migrate(
        address account,
        uint256 vestingAmount,
        uint256 initUnlocked,
        uint256 startTime
    ) external;
}

interface IHodler {
    function add(uint256 amount) external;
}

contract GROVesting is Ownable, Constants {
    using SafeERC20 for IERC20;

    uint256 private constant DEFAULT_MAX_LOCK_PERIOD = ONE_YEAR_SECONDS * 1; // 1 years period
    uint256 private lockPeriodFactor = 10000;

    IMintable public distributer;
    // percentage of tokens that are available immediatly when a vesting postiion is created
    uint256 public immutable initUnlockedPercent;
    // Active airdrops and liquidity pools
    mapping(address => bool) public vesters;

    uint256 public totalLockedAmount;
    address public hodlerClaims;

    IMigrator public migrator;

    struct AccountInfo {
        uint256 total;
        uint256 initUnlocked;
        uint256 startTime;
    }

    mapping(address => AccountInfo) public accountInfos;
    mapping(address => uint256) public withdrawals;

    event LogVester(address vester, bool status);
    event LogMaxLockPeriod(uint256 newMaxPeriod);
    event LogNewMigrator(address newMigrator);

    event LogVest(address indexed user, uint256 totalLockedAmount, uint256 amount, AccountInfo vesting);
    event LogExit(address indexed user, uint256 totalLockedAmount, uint256 vesting, uint256 unlocked, uint256 penalty);
    event LogExtend(address indexed user, uint256 newPeriod, AccountInfo newVesting);
    event LogMigrate(address indexed user, AccountInfo vesting);

    constructor(uint256 _initUnlockedPercent) {
        initUnlockedPercent = _initUnlockedPercent;
    }

    function setDistributer(address _distributer) external onlyOwner {
        distributer = IMintable(_distributer);
    }

    function setHodlerClaims(address _hodlerClaims) external onlyOwner {
        require(_hodlerClaims != address(0));
        hodlerClaims = _hodlerClaims;
    }

    function maxLockPeriod() public view returns (uint256) {
        if (lockPeriodFactor == 0) return 0;
        return (DEFAULT_MAX_LOCK_PERIOD * lockPeriodFactor) / PERCENTAGE_DECIMAL_FACTOR;
    }

    // Adds a new contract that can create vesting positions
    function setVester(address vester, bool status) public onlyOwner {
        vesters[vester] = status;
        emit LogVester(vester, status);
    }

    // Sets amount of time the vesting lasts
    function setMaxLockPeriod(uint256 maxPeriodFactor) external onlyOwner {
        require(maxPeriodFactor <= 20000, "adjustLockPeriod: newFactor > 20000");
        lockPeriodFactor = maxPeriodFactor;
        emit LogMaxLockPeriod(maxLockPeriod());
    }

    function setMigrator(address _migrator) external onlyOwner {
        migrator = IMigrator(_migrator);
        emit LogNewMigrator(_migrator);
    }

    /// @notice Create or modify a vesting position
    /// @param account Account which to add vesting position for
    /// @param amount Amount to add to vesting position
    function vest(address account, uint256 amount) external {
        require(vesters[msg.sender], "vest: !vester");
        require(account != address(0), "vest: !account");
        require(amount > 0, "vest: !amount");

        AccountInfo memory ai = accountInfos[account];
        ai.total += amount;
        uint256 newInitUnlocked = (amount * initUnlockedPercent) / PERCENTAGE_DECIMAL_FACTOR;
        ai.initUnlocked += newInitUnlocked;
        if (ai.startTime == 0) {
            ai.startTime = block.timestamp;
        }

        accountInfos[account] = ai;
        totalLockedAmount += amount;

        emit LogVest(account, totalLockedAmount, amount, ai);
    }

    /// @notice Extend vesting period
    /// @param extension extension to current vesting period
    function extend(uint256 extension) external {
        require(extension <= PERCENTAGE_DECIMAL_FACTOR, "extend: extension > 100%");
        AccountInfo memory ai = accountInfos[msg.sender];
        uint256 _maxLock = maxLockPeriod();
        require(ai.total > 0, "extend: no vesting");
        // if the position is super old, set the extension by moving the starttime back from the current
        //  block by (max lock time) - (desired extension).
        uint256 newPeriod;
        if (ai.startTime + _maxLock < block.timestamp) {
            newPeriod = _maxLock - ((_maxLock * extension) / PERCENTAGE_DECIMAL_FACTOR);
            ai.startTime = block.timestamp - newPeriod;
        } else {
            newPeriod = (_maxLock * extension) / PERCENTAGE_DECIMAL_FACTOR;

            // Cannot extend pass max lock period
            if (ai.startTime + newPeriod >= block.timestamp) {
                ai.startTime = block.timestamp;
            } else {
                ai.startTime = ai.startTime + newPeriod;
            }
        }

        accountInfos[msg.sender] = ai;

        emit LogExtend(msg.sender, newPeriod, ai);
    }

    /// @notice Claim all vested tokens, transfering any unclaimed to the hodler pool
    function exit() external {
        AccountInfo memory ai = accountInfos[msg.sender];
        uint256 total = ai.total;
        require(total > 0, "exit: no vesting");
        uint256 unlocked = unlockedBalance(msg.sender);
        uint256 penalty = total - unlocked;

        delete accountInfos[msg.sender];
        // record account total withdrawal
        withdrawals[msg.sender] += unlocked;
        totalLockedAmount -= total;
        if (penalty > 0) {
            // need implementation
            // IHodler(hodlerClaims).add(penalty);
        }
        distributer.mint(msg.sender, unlocked);

        emit LogExit(msg.sender, totalLockedAmount, total, unlocked, penalty);
    }

    /// @notice Migrate sender's vesting data into a new contract
    function migrate() external {
        require(address(migrator) != address(0), "migrate: !migrator");
        AccountInfo memory ai = accountInfos[msg.sender];
        require(ai.total > 0, "migrate: no vesting");
        migrator.migrate(msg.sender, ai.total, ai.initUnlocked, ai.startTime);
        emit LogMigrate(msg.sender, ai);
    }

    /// @notice See the amount of vested assets the account has accumulated
    /// @param account Account to get vested amount for
    function unlockedBalance(address account) private view returns (uint256 unlocked) {
        AccountInfo memory ai = accountInfos[account];
        if (ai.startTime > 0) {
            uint256 _endTime = ai.startTime + maxLockPeriod();
            if (_endTime > block.timestamp) {
                unlocked =
                    ai.initUnlocked +
                    ((ai.total - ai.initUnlocked) * (block.timestamp - ai.startTime)) /
                    (_endTime - ai.startTime);
            } else {
                unlocked = ai.total;
            }
        }
    }

    /// @notice Get total size of position, vested + vesting
    /// @param account Target account
    function totalBalance(address account) public view returns (uint256 unvested) {
        AccountInfo memory ai = accountInfos[account];
        unvested = ai.total;
    }

    /// @notice Get current vested position
    /// @param account Target account
    function vestedBalance(address account) public view returns (uint256 unvested) {
        return unlockedBalance(account);
    }

    /// @notice Get total vesting amount
    /// @param account Target account
    function vestingBalance(address account) external view returns (uint256) {
        AccountInfo memory ai = accountInfos[account];
        uint256 total = ai.total;
        uint256 unlocked = unlockedBalance(account);
        return total - unlocked;
    }

    /// @notice Get total amount of gro minted to user
    /// @param account Target account
    /// @dev As users can exit and create new vesting positions, this will
    ///     tell the user how much gro they've accrued over all.
    function totalWithdrawn(address account) external view returns (uint256) {
        return withdrawals[account];
    }

    /// @notice Get the start and end date for a vesting position
    /// @param account Target account
    /// @dev userfull for showing the amount of time you've got left
    function getVestingDates(address account) external view returns (uint256, uint256) {
        AccountInfo storage ai = accountInfos[account];
        uint256 _startDate = ai.startTime;
        uint256 _endDate = _startDate + maxLockPeriod();

        return (_startDate, _endDate);
    }
}