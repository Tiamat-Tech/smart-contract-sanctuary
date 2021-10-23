// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 lockedAmount;
        uint256 withdrawn;
    }

    struct PoolInfo {
        uint8 index;
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 totalLocked;
        uint256 originalStartTime;
        uint256 originalEndTime;
    }

    uint256 public constant ALLOWED_VESTING_UPDATE_THRESHOLD = 120 days;

    IERC20 public token;
    PoolInfo[] public lockPools;
    mapping(uint8 => mapping(address => UserInfo)) internal userInfo;

    event BeneficiaryAdded(
        uint8 indexed pid,
        address indexed beneficiary,
        uint256 value
    );
    event Claimed(
        uint8 indexed pid,
        address indexed beneficiary,
        uint256 value
    );
    event VestingPoolInitiated(
        uint8 indexed pid,
        string name,
        uint256 startTime,
        uint256 endTime
    );
    event VestingPoolUpdated(
        uint8 indexed pid,
        string name,
        uint256 startTime,
        uint256 endTime
    );
    event ERC20Recovered(address token, uint256 amount);
    event EtherRecovered(uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    /**
     * @param _token  token address
     * @param _amount amount to be recovered
     *
     * @dev method allows to recover erc20 tokens
     */
    function recoverERC20(address _token, uint256 _amount) external onlyOwner {
        require(
            _token != address(token),
            "TokenVesting: cannot recover vesting tokens"
        );
        IERC20(_token).safeTransfer(_msgSender(), _amount);

        emit ERC20Recovered(_token, _amount);
    }

    /**
     * @dev Allows to recover ether from contract
     */
    function recoverEther() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = _msgSender().call{value: balance}("");
        require(success, "TokenVesting: Failed to send Ether");

        emit EtherRecovered(balance);
    }

    /**
     * @param _name       name of pool
     * @param _startTime  pool start time
     * @param _endTime    pool end time
     *
     * @dev method initialize new vesting pool
     */
    function initVestingPool(
        string calldata _name,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner returns (uint8) {
        require(
            block.timestamp < _startTime,
            "TokenVesting: invalid pool start time"
        );
        require(_startTime < _endTime, "TokenVesting: invalid pool end time");

        uint8 pid = (uint8)(lockPools.length);

        lockPools.push(
            PoolInfo({
                name: _name,
                startTime: _startTime,
                endTime: _endTime,
                originalStartTime: _startTime,
                originalEndTime: _endTime,
                totalLocked: 0,
                index: pid
            })
        );

        emit VestingPoolInitiated(pid, _name, _startTime, _endTime);

        return pid;
    }

    /**
     * @param _pid        pool id
     * @param _name       name of pool
     * @param _startTime  pool start time
     * @param _endTime    pool end time
     *
     * @dev method sets new parameters to the vesting pool
     */
    function setVestingPool(
        uint8 _pid,
        string calldata _name,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(
            lockPools[_pid].startTime != 0,
            "TokenVesting: pool does not exist"
        );
        require(
            lockPools[_pid].startTime > block.timestamp,
            "TokenVesting: pool is already running"
        );
        require(
            _startTime > block.timestamp,
            "TokenVesting: invalid pool start time"
        );
        require(_startTime < _endTime, "TokenVesting: invalid pool end time");

        require(
            lockPools[_pid].originalStartTime.add(
                ALLOWED_VESTING_UPDATE_THRESHOLD
            ) >= _startTime,
            "TokenVesting: new start date is to large"
        );
        require(
            lockPools[_pid].originalStartTime.sub(
                ALLOWED_VESTING_UPDATE_THRESHOLD
            ) <= _startTime,
            "TokenVesting: new start date is to small"
        );
        require(
            lockPools[_pid].originalEndTime.add(
                ALLOWED_VESTING_UPDATE_THRESHOLD
            ) >= _endTime,
            "TokenVesting: new end date is to large"
        );
        require(
            lockPools[_pid].originalEndTime.sub(
                ALLOWED_VESTING_UPDATE_THRESHOLD
            ) <= _endTime,
            "TokenVesting: new end date is to small"
        );

        lockPools[_pid].name = _name;
        lockPools[_pid].startTime = _startTime;
        lockPools[_pid].endTime = _endTime;

        emit VestingPoolUpdated(_pid, _name, _startTime, _endTime);
    }

    /**
     * @param _pid            pool id
     * @param _beneficiary    new beneficiary
     * @param _lockedAmount   amount to be locked for distribution
     *
     * @dev method adds new beneficiary to the pool
     */
    function addBeneficiary(
        uint8 _pid,
        address _beneficiary,
        uint256 _lockedAmount
    ) external {
        require(_pid < lockPools.length, "TokenVesting: non existing pool");

        token.safeTransferFrom(_msgSender(), address(this), _lockedAmount);
        userInfo[_pid][_beneficiary].lockedAmount = userInfo[_pid][_beneficiary]
            .lockedAmount
            .add(_lockedAmount);
        lockPools[_pid].totalLocked = lockPools[_pid].totalLocked.add(
            _lockedAmount
        );

        emit BeneficiaryAdded(_pid, _beneficiary, _lockedAmount);
    }

    /**
     * @param _pid            pool id
     * @param _beneficiaries  array of beneficiaries
     * @param _lockedAmounts   array of amounts to be locked for distribution
     *
     * @dev method adds new beneficiaries to the pool
     */
    function addBeneficiaryBatches(
        uint8 _pid,
        address[] calldata _beneficiaries,
        uint256[] calldata _lockedAmounts
    ) external {
        require(
            _beneficiaries.length == _lockedAmounts.length,
            "TokenVesting: params invalid length"
        );
        require(_pid < lockPools.length, "TokenVesting: non existing pool");

        uint256 totalLockedAmounts;
        for (uint8 i = 0; i < _lockedAmounts.length; i++) {
            totalLockedAmounts = totalLockedAmounts.add(_lockedAmounts[i]);
        }
        token.safeTransferFrom(_msgSender(), address(this), totalLockedAmounts);

        uint256 beneficiariesLength = _beneficiaries.length;
        for (uint8 i = 0; i < beneficiariesLength; i++) {
            address beneficiary = _beneficiaries[i];
            uint256 lockedAmount = _lockedAmounts[i];

            userInfo[_pid][beneficiary].lockedAmount = userInfo[_pid][
                beneficiary
            ].lockedAmount.add(lockedAmount);
            lockPools[_pid].totalLocked = lockPools[_pid].totalLocked.add(
                lockedAmount
            );

            emit BeneficiaryAdded(_pid, beneficiary, lockedAmount);
        }
    }

    /**
     * @param _pid  pool id
     *
     * @dev method allows to claim beneficiary locked amount
     */
    function claim(uint8 _pid) external returns (uint256 amount) {
        amount = getReleasableAmount(_pid, _msgSender());
        require(amount > 0, "TokenVesting: can't claim 0 amount");

        userInfo[_pid][_msgSender()].withdrawn = userInfo[_pid][_msgSender()]
            .withdrawn
            .add(amount);
        token.safeTransfer(_msgSender(), amount);

        emit Claimed(_pid, _msgSender(), amount);
    }

    /**
     * @param _pid          pool id
     * @param _beneficiary  beneficiary address
     *
     * @dev method returns amount of releasable funds per beneficiary
     */
    function getReleasableAmount(uint8 _pid, address _beneficiary)
        public
        view
        returns (uint256)
    {
        return
            getVestedAmount(_pid, _beneficiary, block.timestamp).sub(
                userInfo[_pid][_beneficiary].withdrawn
            );
    }

    /**
     * @param _pid          pool id
     * @param _beneficiary  beneficiary address
     * @param _time         time of vesting
     *
     * @dev method returns amount of available for vesting token per beneficiary and time
     */
    function getVestedAmount(
        uint8 _pid,
        address _beneficiary,
        uint256 _time
    ) public view returns (uint256) {
        if (_pid >= lockPools.length) {
            return 0;
        }

        if (_time < lockPools[_pid].startTime) {
            return 0;
        }

        uint256 lockedAmount = userInfo[_pid][_beneficiary].lockedAmount;
        if (lockedAmount == 0) {
            return 0;
        }

        uint256 vestingDuration = lockPools[_pid].endTime.sub(
            lockPools[_pid].startTime
        );
        uint256 timeDuration = _time.sub(lockPools[_pid].startTime);
        uint256 amount = lockedAmount.mul(timeDuration).div(vestingDuration);

        if (amount > lockedAmount) {
            amount = lockedAmount;
        }
        return amount;
    }

    /**
     * @param _pid          pool id
     * @param _beneficiary  beneficiary address
     *
     * @dev method returns beneficiary details per pool
     */
    function getBeneficiaryInfo(uint8 _pid, address _beneficiary)
        external
        view
        returns (
            address beneficiary,
            uint256 totalLocked,
            uint256 withdrawn,
            uint256 releasableAmount,
            uint256 currentTime
        )
    {
        beneficiary = _beneficiary;
        currentTime = block.timestamp;

        if (_pid < lockPools.length) {
            totalLocked = userInfo[_pid][_beneficiary].lockedAmount;
            withdrawn = userInfo[_pid][_beneficiary].withdrawn;
            releasableAmount = getReleasableAmount(_pid, _beneficiary);
        }
    }

    /**
     *
     * @dev method returns amount of pools
     */
    function getPoolsCount() external view returns (uint256 poolsCount) {
        return lockPools.length;
    }

    /**
     * @param _pid pool id
     *
     * @dev method returns pool details
     */
    function getPoolInfo(uint8 _pid)
        external
        view
        returns (
            string memory name,
            uint256 totalLocked,
            uint256 startTime,
            uint256 endTime
        )
    {
        if (_pid < lockPools.length) {
            name = lockPools[_pid].name;
            totalLocked = lockPools[_pid].totalLocked;
            startTime = lockPools[_pid].startTime;
            endTime = lockPools[_pid].endTime;
        }
    }

    /**
     *
     * @dev method returns total locked funds
     */
    function getTotalLocked() external view returns (uint256 totalLocked) {
        for (uint8 i = 0; i < lockPools.length; i++) {
            totalLocked = totalLocked.add(lockPools[i].totalLocked);
        }
    }
}