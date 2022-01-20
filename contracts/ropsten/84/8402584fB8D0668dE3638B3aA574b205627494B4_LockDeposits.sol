//SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/V4/access/Ownable.sol";

import "./Error.sol";

interface Token {
    function decimals() external returns (uint256);
    function mint(address, uint256) external;
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

contract LockDeposits is Ownable {
    struct Deposit {
        // total supply of UMB can be saved using 89bits, so we good with 128
        // TODO check if for MC it will be the same
        uint128 amount;
        uint128 rewardPaid;
        uint32 startDate;
        uint32 finishDate;
        uint32 apy;
        uint32 withdrawnAt;
    }

    struct Setting {
        // duration in seconds => multiplier
        mapping(uint32 => uint32) multipliers;
        uint32 baseRate;
    }

    uint32 public constant SECONDS_PER_YEAR = 365 days;

    /// @dev decimals for: baseRate, APY, multipliers
    ///         eg for baseRate: 1e6 is 1%, 50e6 is 50%
    ///         eg for multipliers: 1e6 is 1.0x, 3210000 is 3.21x
    uint32 public constant RATE_DECIMALS = 10 ** 6;

    Token public immutable rewardToken;

    /// @dev staking token => dedicated settings
    mapping(address => Setting) public settings;

    /// @dev user => staking token => deposit index => Deposit
    mapping(address => mapping(address => mapping(uint256 => Deposit))) public deposits;

    /// @dev user => staking token => deposit next index
    mapping(address => mapping(address => uint256)) public depositNextIndex;

    event LogTokenSettings(address indexed token, uint32 baseRate, uint32 period, uint32 multiplier);
    event LogTokenRemoved(address indexed token);
    event LogDeposit(address indexed token, address indexed user, uint256 depositIndex, uint256 amount);
    event LogRewardClaimed(address indexed token, address indexed user, uint256 depositIndex, uint256 amount);
    event LogWithdraw(address indexed token, address indexed user, uint256 depositIndex, uint256 amount);

    constructor(address _rewardToken) {
        if (Token(_rewardToken).decimals() != 18) revert TokenNotSupported();

        rewardToken = Token(_rewardToken);
    }

    function turnOffTokens(address[] calldata _tokens) external onlyOwner {
        for (uint256 i; i < _tokens.length; i++) {
            settings[_tokens[i]].baseRate = 0;
            emit LogTokenRemoved(_tokens[i]);
        }
    }

    function setStakingTokenSettings(
        address _token,
        uint32 _baseRate,
        uint32[] calldata _periods,
        uint32[] calldata _multipliers
    )
        external
        onlyOwner
    {
        if (_baseRate == 0) revert EmptyBaseRate();
        if (_periods.length == 0) revert EmptyPeriods();
        if (_periods.length != _multipliers.length) revert ArraysNotMatch();
        if (Token(_token).decimals() != 18) revert TokenNotSupported();

        Setting storage setting = settings[_token];
        setting.baseRate = _baseRate;

        for (uint256 i; i < _periods.length; i++) {
            if (_periods[i] == 0 || _multipliers[i] == 0) revert InvalidSettings();

            setting.multipliers[_periods[i]] = _multipliers[i];
            emit LogTokenSettings(_token, _baseRate, _periods[i], _multipliers[i]);
        }
    }

    function lock(address _token, uint32 _period, uint256 _amount) external virtual {
        unchecked {
            uint256 nextIndex = depositNextIndex[msg.sender][_token];
            Deposit storage deposit = deposits[msg.sender][_token][nextIndex];
            uint256 baseRate = uint256(settings[_token].baseRate);

            if (baseRate == 0) revert InvalidDepositToken();

            // we do not support unknown tokens, so no need for safe transfer
            if (!Token(_token).transferFrom(msg.sender, address(this), _amount)) revert TokenTransferFailed();

            uint256 multiplier = uint256(settings[_token].multipliers[_period]);
            if (multiplier == 0) revert InvalidPeriod();

            uint32 now32 = uint32(block.timestamp);

            deposit.amount = uint128(_amount);
            deposit.startDate = now32;
            deposit.finishDate = now32 + _period;
            deposit.apy = uint32(baseRate * multiplier / RATE_DECIMALS);

            depositNextIndex[msg.sender][_token] = nextIndex + 1;

            emit LogDeposit(_token, msg.sender, nextIndex, _amount);
        }
    }

    function exit(address[] calldata _tokens, uint256[] calldata _indexes) external {
        for (uint256 i; i < _tokens.length; i++) {
            claim(_tokens[i], _indexes[i]);
            withdraw(_tokens[i], _indexes[i]);
        }
    }

    function claimMany(address[] calldata _tokens, uint256[] calldata _indexes) external {
        for (uint256 i; i < _tokens.length; i++) {
            claim(_tokens[i], _indexes[i]);
        }
    }

    function withdrawMany(address[] calldata _tokens, uint256[] calldata _indexes) external {
        for (uint256 i; i < _tokens.length; i++) {
            withdraw(_tokens[i], _indexes[i]);
        }
    }

    /// @return totalReward total amount of reward token that user earned so far during lock period
    /// @return pendingReward pending amount of reward token available for claim
    function claimable(address _user, address _token, uint256 _index)
        external
        view
        returns (uint256 totalReward, uint256 pendingReward)
    {
        return _claimable(deposits[_user][_token][_index]);
    }

    /// @return reward amount that has been claimed by user so far
    function paid(address _user, address _token, uint256 _index) external view returns (uint256) {
        return deposits[_user][_token][_index].rewardPaid;
    }

    function claim(address _token, uint256 _index) public {
        uint256 amountToMint = _claimReward(_token, _index);
        rewardToken.mint(msg.sender, amountToMint);
    }

    function withdraw(address _token, uint256 _index) public {
        unchecked {
            Deposit storage deposit = deposits[msg.sender][_token][_index];
            uint32 withdrawnAt = deposit.withdrawnAt;
            if (withdrawnAt != 0) revert DepositAlreadyWithdrawn();

            if (block.timestamp < deposit.finishDate) revert DepositLocked();

            uint256 amount = deposit.amount;
            if (amount == 0) return;

            deposit.withdrawnAt = uint32(block.timestamp);

            emit LogWithdraw(_token, msg.sender, _index, amount);
            Token(_token).transfer(msg.sender, amount);
        }
    }


    /// @return totalLocked total amount of `_token` locked by user
    /// @return reward total reward of `rewardToken` earned so far
    function balanceOf(address _token, address _address) public view returns (uint256 totalLocked, uint256 reward) {
        unchecked {
            uint256 lastIndex = depositNextIndex[_address][_token];
            uint256 timestamp = block.timestamp;

            for (uint256 i; i < lastIndex; i++) {
                Deposit memory deposit = deposits[_address][_token][i];
                if (deposit.withdrawnAt == 0) totalLocked += deposit.amount;

                reward += _calculateReward(deposit, timestamp) - deposit.rewardPaid;
            }
        }
    }
    function _claimReward(address _token, uint256 _index) internal returns (uint256 amountToMint) {
        Deposit memory deposit = deposits[msg.sender][_token][_index];

        (uint256 totalReward, uint256 pendingReward) = _claimable(deposit);
        if (pendingReward == 0) revert NothingToClaim();

        deposits[msg.sender][_token][_index].rewardPaid = uint128(totalReward);

        emit LogRewardClaimed(_token, msg.sender, _index, pendingReward);

        return pendingReward;
    }

    function _claimable(Deposit memory _deposit) internal view returns (uint256 totalReward, uint256 pendingReward) {
        unchecked {
            totalReward = _calculateReward(_deposit, block.timestamp);
            pendingReward = totalReward - _deposit.rewardPaid;
        }
    }

    function _calculateReward(Deposit memory _deposit, uint256 _timestamp) internal pure returns (uint256 reward) {
        unchecked {
            uint256 deltaTime =
                (_timestamp < _deposit.finishDate ? _timestamp : _deposit.finishDate) - _deposit.startDate;

            reward = _deposit.amount * _deposit.apy * deltaTime / SECONDS_PER_YEAR / RATE_DECIMALS;
        }
    }
}