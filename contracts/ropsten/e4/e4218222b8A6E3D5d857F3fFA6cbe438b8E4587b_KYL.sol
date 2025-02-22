// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library AttoDecimal {
    using SafeMath for uint256;

    struct Instance {
        uint256 mantissa;
    }

    uint256 internal constant BASE = 10;
    uint256 internal constant EXPONENTIATION = 18;
    uint256 internal constant ONE_MANTISSA = BASE**EXPONENTIATION;
    uint256 internal constant ONE_TENTH_MANTISSA = ONE_MANTISSA / 10;
    uint256 internal constant HALF_MANTISSA = ONE_MANTISSA / 2;
    uint256 internal constant SQUARED_ONE_MANTISSA = ONE_MANTISSA * ONE_MANTISSA;
    uint256 internal constant MAX_INTEGER = type(uint128).max / ONE_MANTISSA;

    function maximum() internal pure returns (Instance memory) {
        return Instance({mantissa: type(uint128).max});
    }

    function zero() internal pure returns (Instance memory) {
        return Instance({mantissa: 0});
    }

    function one() internal pure returns (Instance memory) {
        return Instance({mantissa: ONE_MANTISSA});
    }

    function convert(uint256 integer) internal pure returns (Instance memory) {
        return Instance({mantissa: integer.mul(ONE_MANTISSA)});
    }

    function compare(Instance memory a, Instance memory b) internal pure returns (int8) {
        if (a.mantissa < b.mantissa) return -1;
        return int8(a.mantissa > b.mantissa ? 1 : 0);
    }

    function compare(Instance memory a, uint256 b) internal pure returns (int8) {
        return compare(a, convert(b));
    }

    function add(Instance memory a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.add(b.mantissa)});
    }

    function add(Instance memory a, uint256 b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.add(b.mul(ONE_MANTISSA))});
    }

    function sub(Instance memory a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.sub(b.mantissa)});
    }

    function sub(Instance memory a, uint256 b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.sub(b.mul(ONE_MANTISSA))});
    }

    function sub(uint256 a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mul(ONE_MANTISSA).sub(b.mantissa)});
    }

    function mul(Instance memory a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.mul(b.mantissa) / ONE_MANTISSA});
    }

    function mul(Instance memory a, uint256 b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.mul(b)});
    }

    function div(Instance memory a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.mul(ONE_MANTISSA).div(b.mantissa)});
    }

    function div(Instance memory a, uint256 b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.mul(ONE_MANTISSA).div(b)});
    }

    function div(uint256 a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mul(SQUARED_ONE_MANTISSA).div(b.mantissa)});
    }

    function div(uint256 a, uint256 b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mul(ONE_MANTISSA).div(b)});
    }

    function idiv(Instance memory a, Instance memory b) internal pure returns (uint256) {
        return a.mantissa.div(b.mantissa);
    }

    function idiv(Instance memory a, uint256 b) internal pure returns (uint256) {
        return a.mantissa.div(b.mul(ONE_MANTISSA));
    }

    function idiv(uint256 a, Instance memory b) internal pure returns (uint256) {
        return a.mul(ONE_MANTISSA).div(b.mantissa);
    }

    function mod(Instance memory a, Instance memory b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.mod(b.mantissa)});
    }

    function mod(Instance memory a, uint256 b) internal pure returns (Instance memory) {
        return Instance({mantissa: a.mantissa.mod(b.mul(ONE_MANTISSA))});
    }

    function mod(uint256 a, Instance memory b) internal pure returns (Instance memory) {
        if (a > MAX_INTEGER) return Instance({mantissa: a.mod(b.mantissa).mul(ONE_MANTISSA) % b.mantissa});
        return Instance({mantissa: a.mul(ONE_MANTISSA).mod(b.mantissa)});
    }

    function floor(Instance memory a) internal pure returns (uint256) {
        return a.mantissa / ONE_MANTISSA;
    }

    function ceil(Instance memory a) internal pure returns (uint256) {
        return (a.mantissa / ONE_MANTISSA) + (a.mantissa % ONE_MANTISSA > 0 ? 1 : 0);
    }

    function round(Instance memory a) internal pure returns (uint256) {
        return (a.mantissa / ONE_MANTISSA) + ((a.mantissa / ONE_TENTH_MANTISSA) % 10 >= 5 ? 1 : 0);
    }

    function eq(Instance memory a, Instance memory b) internal pure returns (bool) {
        return a.mantissa == b.mantissa;
    }

    function eq(Instance memory a, uint256 b) internal pure returns (bool) {
        if (b > MAX_INTEGER) return false;
        return a.mantissa == b * ONE_MANTISSA;
    }

    function gt(Instance memory a, Instance memory b) internal pure returns (bool) {
        return a.mantissa > b.mantissa;
    }

    function gt(Instance memory a, uint256 b) internal pure returns (bool) {
        if (b > MAX_INTEGER) return false;
        return a.mantissa > b * ONE_MANTISSA;
    }

    function gte(Instance memory a, Instance memory b) internal pure returns (bool) {
        return a.mantissa >= b.mantissa;
    }

    function gte(Instance memory a, uint256 b) internal pure returns (bool) {
        if (b > MAX_INTEGER) return false;
        return a.mantissa >= b * ONE_MANTISSA;
    }

    function lt(Instance memory a, Instance memory b) internal pure returns (bool) {
        return a.mantissa < b.mantissa;
    }

    function lt(Instance memory a, uint256 b) internal pure returns (bool) {
        if (b > MAX_INTEGER) return true;
        return a.mantissa < b * ONE_MANTISSA;
    }

    function lte(Instance memory a, Instance memory b) internal pure returns (bool) {
        return a.mantissa <= b.mantissa;
    }

    function lte(Instance memory a, uint256 b) internal pure returns (bool) {
        if (b > MAX_INTEGER) return true;
        return a.mantissa <= b * ONE_MANTISSA;
    }

    function isInteger(Instance memory a) internal pure returns (bool) {
        return a.mantissa % ONE_MANTISSA == 0;
    }

    function isPositive(Instance memory a) internal pure returns (bool) {
        return a.mantissa > 0;
    }

    function isZero(Instance memory a) internal pure returns (bool) {
        return a.mantissa == 0;
    }

    function sum(Instance[] memory array) internal pure returns (Instance memory result) {
        uint256 length = array.length;
        for (uint256 index = 0; index < length; index++) result = add(result, array[index]);
    }

    function toTuple(Instance memory a)
        internal
        pure
        returns (
            uint256 mantissa,
            uint256 base,
            uint256 exponentiation
        )
    {
        return (a.mantissa, BASE, EXPONENTIATION);
    }
}

abstract contract TwoStageOwnable {
    address private _nominatedOwner;
    address private _owner;

    function nominatedOwner() public view returns (address) {
        return _nominatedOwner;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    event OwnerChanged(address indexed newOwner);
    event OwnerNominated(address indexed nominatedOwner);

    constructor(address owner_) internal {
        require(owner_ != address(0), "Owner is zero");
        _setOwner(owner_);
    }

    function acceptOwnership() external returns (bool success) {
        require(msg.sender == _nominatedOwner, "Not nominated to ownership");
        _setOwner(_nominatedOwner);
        return true;
    }

    function nominateNewOwner(address owner_) external onlyOwner returns (bool success) {
        _nominateNewOwner(owner_);
        return true;
    }

    modifier onlyOwner {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    function _nominateNewOwner(address owner_) internal {
        if (_nominatedOwner == owner_) return;
        require(_owner != owner_, "Already owner");
        _nominatedOwner = owner_;
        emit OwnerNominated(owner_);
    }

    function _setOwner(address newOwner) internal {
        if (_owner == newOwner) return;
        _owner = newOwner;
        _nominatedOwner = address(0);
        emit OwnerChanged(newOwner);
    }
}


contract KYL is ERC20, ReentrancyGuard, TwoStageOwnable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using AttoDecimal for AttoDecimal.Instance;

    struct Strategy {
        uint256 endBlockNumber;
        uint256 perBlockReward;
        uint256 startBlockNumber;
    }

    struct Unstake {
        uint256 amount;
        uint256 applicableAt;
    }

    uint256 public constant MIN_STAKE_BALANCE = 10**18;

    uint256 public claimingFeePercent;
    uint256 public lastUpdateBlockNumber;

    uint256 private _feePool;
    uint256 private _lockedRewards;
    uint256 private _totalStaked;
    uint256 private _totalUnstaked;
    uint256 private _unstakingTime;
    IERC20 private _stakingToken;

    AttoDecimal.Instance private _defaultPrice;
    AttoDecimal.Instance private _price;
    Strategy private _currentStrategy;
    Strategy private _nextStrategy;

    mapping(address => Unstake) private _unstakes;

    function getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    function getTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function feePool() public view returns (uint256) {
        return _feePool;
    }

    function lockedRewards() public view returns (uint256) {
        return _lockedRewards;
    }

    function totalStaked() public view returns (uint256) {
        return _totalStaked;
    }

    function totalUnstaked() public view returns (uint256) {
        return _totalUnstaked;
    }

    function stakingToken() public view returns (IERC20) {
        return _stakingToken;
    }

    function unstakingTime() public view returns (uint256) {
        return _unstakingTime;
    }

    function currentStrategy() public view returns (Strategy memory) {
        return _currentStrategy;
    }

    function nextStrategy() public view returns (Strategy memory) {
        return _nextStrategy;
    }

    function getUnstake(address account) public view returns (Unstake memory result) {
        result = _unstakes[account];
    }

    function defaultPrice()
        external
        view
        returns (
            uint256 mantissa,
            uint256 base,
            uint256 exponentiation
        )
    {
        return _defaultPrice.toTuple();
    }

    function getCurrentStrategyUnlockedRewards() public view returns (uint256 unlocked) {
        unlocked = _getStrategyUnlockedRewards(_currentStrategy);
    }

    function getUnlockedRewards() public view returns (uint256 unlocked, bool currentStrategyEnded) {
        unlocked = _getStrategyUnlockedRewards(_currentStrategy);
        if (getBlockNumber() >= _currentStrategy.endBlockNumber) {
            currentStrategyEnded = true;
            if (_nextStrategy.endBlockNumber != 0) unlocked = unlocked.add(_getStrategyUnlockedRewards(_nextStrategy));
        }
    }

    /// @notice Calculates price of synthetic token for current block
    function price()
        public
        view
        returns (
            uint256 mantissa,
            uint256 base,
            uint256 exponentiation
        )
    {
        (uint256 unlocked, ) = getUnlockedRewards();
        uint256 totalStaked_ = _totalStaked;
        uint256 totalSupply_ = totalSupply();
        AttoDecimal.Instance memory result = _defaultPrice;
        if (totalSupply_ > 0) result = AttoDecimal.div(totalStaked_.add(unlocked), totalSupply_);
        return result.toTuple();
    }

    /// @notice Returns last updated price of synthetic token
    function priceStored()
        public
        view
        returns (
            uint256 mantissa,
            uint256 base,
            uint256 exponentiation
        )
    {
        return _price.toTuple();
    }

    /// @notice Calculates expected result of swapping synthetic tokens for staking tokens
    /// @param account Account that wants to swap
    /// @param amount Minimum amount of staking tokens that should be received at swapping process
    /// @return unstakedAmount Amount of staking tokens that should be received at swapping process
    /// @return burnedAmount Amount of synthetic tokens that should be burned at swapping process
    function calculateUnstake(address account, uint256 amount)
        public
        view
        returns (uint256 unstakedAmount, uint256 burnedAmount)
    {
        (uint256 mantissa_, , ) = price();
        return _calculateUnstake(account, amount, AttoDecimal.Instance(mantissa_));
    }

    event Claimed(
        address indexed account,
        uint256 requestedAmount,
        uint256 claimedAmount,
        uint256 feeAmount,
        uint256 burnedAmount
    );

    event ClaimingFeePercentUpdated(uint256 feePercent);
    event CurrentStrategyUpdated(uint256 perBlockReward, uint256 startBlockNumber, uint256 endBlockNumber);
    event FeeClaimed(address indexed receiver, uint256 amount);

    event Migrated(
        address indexed account,
        uint256 omTokenV1StakeAmount,
        uint256 stakingPoolV1Reward,
        uint256 stakingPoolV2Reward
    );

    event NextStrategyUpdated(uint256 perBlockReward, uint256 startBlockNumber, uint256 endBlockNumber);
    event UnstakingTimeUpdated(uint256 unstakingTime);
    event NextStrategyRemoved();
    event PoolDecreased(uint256 amount);
    event PoolIncreased(address indexed payer, uint256 amount);
    event PriceUpdated(uint256 mantissa, uint256 base, uint256 exponentiation);
    event RewardsUnlocked(uint256 amount);
    event Staked(address indexed account, address indexed payer, uint256 stakedAmount, uint256 mintedAmount);
    event Unstaked(address indexed account, uint256 requestedAmount, uint256 unstakedAmount, uint256 burnedAmount);
    event UnstakingCanceled(address indexed account, uint256 amount);
    event Withdrawed(address indexed account, uint256 amount);

    constructor(
        string memory syntheticTokenName,
        string memory syntheticTokenSymbol,
        IERC20 stakingToken_,
        address owner_,
        uint256 claimingFeePercent_,
        uint256 perBlockReward_,
        uint256 startBlockNumber_,
        uint256 duration_,
        uint256 unstakingTime_,
        uint256 defaultPriceMantissa
    ) public TwoStageOwnable(owner_) ERC20(syntheticTokenName, syntheticTokenSymbol) {
        _defaultPrice = AttoDecimal.Instance(defaultPriceMantissa);
        _stakingToken = stakingToken_;
        _setClaimingFeePercent(claimingFeePercent_);
        _validateStrategyParameters(perBlockReward_, startBlockNumber_, duration_);
        _setUnstakingTime(unstakingTime_);
        _setCurrentStrategy(perBlockReward_, startBlockNumber_, startBlockNumber_.add(duration_));
        lastUpdateBlockNumber = getBlockNumber();
        _price = _defaultPrice;
    }

    /// @notice Cancels unstaking by staking locked for withdrawals tokens
    /// @param amount Amount of locked for withdrawals tokens
    function cancelUnstaking(uint256 amount) external onlyPositiveAmount(amount) returns (bool success) {
        _update();
        address caller = msg.sender;
        Unstake storage unstake_ = _unstakes[caller];
        uint256 unstakingAmount = unstake_.amount;
        require(unstakingAmount >= amount, "Not enough unstaked balance");
        uint256 stakedAmount = _price.mul(balanceOf(caller)).floor();
        require(stakedAmount.add(amount) >= MIN_STAKE_BALANCE, "Stake balance lt min stake");
        uint256 synthAmount = AttoDecimal.div(amount, _price).floor();
        _mint(caller, synthAmount);
        _totalStaked = _totalStaked.add(amount);
        _totalUnstaked = _totalUnstaked.sub(amount);
        unstake_.amount = unstakingAmount.sub(amount);
        emit Staked(caller, address(0), amount, synthAmount);
        emit UnstakingCanceled(caller, amount);
        return true;
    }

    /// @notice Swaps synthetic tokens for staking tokens and immediately sends them to the caller but takes some fee
    /// @param amount Staking tokens amount to swap for. Fee will be taked from this amount
    /// @return claimedAmount Amount of staking tokens that was been sended to caller
    /// @return burnedAmount Amount of synthetic tokens that was burned while swapping
    function claim(uint256 amount)
        external
        onlyPositiveAmount(amount)
        returns (uint256 claimedAmount, uint256 burnedAmount)
    {
        _update();
        address caller = msg.sender;
        (claimedAmount, burnedAmount) = _calculateUnstake(caller, amount, _price);
        uint256 fee = claimedAmount.mul(claimingFeePercent).div(100);
        _burn(caller, burnedAmount);
        _totalStaked = _totalStaked.sub(claimedAmount);
        claimedAmount = claimedAmount.sub(fee);
        _feePool = _feePool.add(fee);
        emit Claimed(caller, amount, claimedAmount, fee, burnedAmount);
        _stakingToken.safeTransfer(caller, claimedAmount);
    }

    /// @notice Withdraws all staking tokens, that have been accumulated in imidiatly claiming process.
    ///     Allowed to be called only by the owner
    /// @return amount Amount of accumulated and withdrawed tokens
    function claimFees() external onlyOwner returns (uint256 amount) {
        require(_feePool > 0, "No fees");
        amount = _feePool;
        _feePool = 0;
        emit FeeClaimed(owner(), amount);
        _stakingToken.safeTransfer(owner(), amount);
    }

    /// @notice Creates new strategy. Allowed to be called only by the owner
    /// @param perBlockReward_ Reward that should be added to common staking tokens pool every block
    /// @param startBlockNumber_ Number of block from which strategy should starts
    /// @param duration_ Blocks count for which new strategy should be applied
    function createNewStrategy(
        uint256 perBlockReward_,
        uint256 startBlockNumber_,
        uint256 duration_
    ) public onlyOwner returns (bool success) {
        _update();
        _validateStrategyParameters(perBlockReward_, startBlockNumber_, duration_);
        uint256 endBlockNumber = startBlockNumber_.add(duration_);
        Strategy memory strategy =
            Strategy({
                perBlockReward: perBlockReward_,
                startBlockNumber: startBlockNumber_,
                endBlockNumber: endBlockNumber
            });
        if (_currentStrategy.startBlockNumber > getBlockNumber()) {
            delete _nextStrategy;
            emit NextStrategyRemoved();
            _currentStrategy = strategy;
            emit CurrentStrategyUpdated(perBlockReward_, startBlockNumber_, endBlockNumber);
        } else {
            emit NextStrategyUpdated(perBlockReward_, startBlockNumber_, endBlockNumber);
            _nextStrategy = strategy;
            if (_currentStrategy.endBlockNumber > startBlockNumber_) {
                _currentStrategy.endBlockNumber = startBlockNumber_;
                emit CurrentStrategyUpdated(
                    _currentStrategy.perBlockReward,
                    _currentStrategy.startBlockNumber,
                    startBlockNumber_
                );
            }
        }
        return true;
    }

    function decreasePool(uint256 amount) external onlyPositiveAmount(amount) onlyOwner returns (bool success) {
        _update();
        _lockedRewards = _lockedRewards.sub(amount, "Not enough locked rewards");
        emit PoolDecreased(amount);
        _stakingToken.safeTransfer(owner(), amount);
        return true;
    }

    /// @notice Increases pool of rewards
    /// @param amount Amount of staking tokens (in wei) that should be added to rewards pool
    function increasePool(uint256 amount) external onlyPositiveAmount(amount) returns (bool success) {
        _update();
        address payer = msg.sender;
        _lockedRewards = _lockedRewards.add(amount);
        emit PoolIncreased(payer, amount);
        _stakingToken.safeTransferFrom(payer, address(this), amount);
        return true;
    }

    /// @notice Change claiming fee percent. Can be called only by the owner
    /// @param feePercent New claiming fee percent
    function setClaimingFeePercent(uint256 feePercent) external onlyOwner returns (bool success) {
        _setClaimingFeePercent(feePercent);
        return true;
    }

    /// @notice Converts staking tokens to synthetic tokens
    /// @param amount Amount of staking tokens to be swapped
    /// @return mintedAmount Amount of synthetic tokens that was received at swapping process
    function stake(uint256 amount) external onlyPositiveAmount(amount) returns (uint256 mintedAmount) {
        address staker = msg.sender;
        return _stake(staker, staker, amount);
    }

    /// @notice Converts staking tokens to synthetic tokens and sends them to specific account
    /// @param account Receiver of synthetic tokens
    /// @param amount Amount of staking tokens to be swapped
    /// @return mintedAmount Amount of synthetic tokens that was received by specified account at swapping process
    function stakeForUser(address account, uint256 amount)
        external
        onlyPositiveAmount(amount)
        returns (uint256 mintedAmount)
    {
        return _stake(account, msg.sender, amount);
    }

    /// @notice Swapes synthetic tokens for staking tokens and locks them for some period
    /// @param amount Minimum amount of staking tokens that should be locked after swapping process
    /// @return unstakedAmount Amount of staking tokens that was locked
    /// @return burnedAmount Amount of synthetic tokens that was burned
    function unstake(uint256 amount)
        external
        onlyPositiveAmount(amount)
        returns (uint256 unstakedAmount, uint256 burnedAmount)
    {
        _update();
        address caller = msg.sender;
        (unstakedAmount, burnedAmount) = _calculateUnstake(caller, amount, _price);
        _burn(caller, burnedAmount);
        _totalStaked = _totalStaked.sub(unstakedAmount);
        _totalUnstaked = _totalUnstaked.add(unstakedAmount);
        Unstake storage unstake_ = _unstakes[caller];
        unstake_.amount = unstake_.amount.add(unstakedAmount);
        unstake_.applicableAt = getTimestamp().add(_unstakingTime);
        emit Unstaked(caller, amount, unstakedAmount, burnedAmount);
    }

    /// @notice Updates price of synthetic token
    /// @dev Automatically has been called on every contract action, that uses or can affect price
    function update() external returns (bool success) {
        _update();
        return true;
    }

    /// @notice Withdraws unstaked staking tokens
    function withdraw() external returns (bool success) {
        address caller = msg.sender;
        Unstake storage unstake_ = _unstakes[caller];
        uint256 amount = unstake_.amount;
        require(amount > 0, "Not unstaked");
        require(unstake_.applicableAt <= getTimestamp(), "Not released at");
        delete _unstakes[caller];
        _totalUnstaked = _totalUnstaked.sub(amount);
        emit Withdrawed(caller, amount);
        _stakingToken.safeTransfer(caller, amount);
        return true;
    }

    /// @notice Change unstaking time. Can be called only by the owner
    /// @param unstakingTime_ New unstaking process duration in seconds
    function setUnstakingTime(uint256 unstakingTime_) external onlyOwner returns (bool success) {
        _setUnstakingTime(unstakingTime_);
        return true;
    }

    function _getStrategyUnlockedRewards(Strategy memory strategy_) internal view returns (uint256 unlocked) {
        uint256 currentBlockNumber = getBlockNumber();
        if (currentBlockNumber < strategy_.startBlockNumber || currentBlockNumber == lastUpdateBlockNumber) {
            return unlocked;
        }
        uint256 lastRewardedBlockNumber = Math.max(lastUpdateBlockNumber, strategy_.startBlockNumber);
        uint256 lastRewardableBlockNumber = Math.min(currentBlockNumber, strategy_.endBlockNumber);
        if (lastRewardedBlockNumber < lastRewardableBlockNumber) {
            uint256 blocksDiff = lastRewardableBlockNumber.sub(lastRewardedBlockNumber);
            unlocked = unlocked.add(blocksDiff.mul(strategy_.perBlockReward));
        }
    }

    function _calculateUnstake(
        address account,
        uint256 amount,
        AttoDecimal.Instance memory price_
    ) internal view returns (uint256 unstakedAmount, uint256 burnedAmount) {
        unstakedAmount = amount;
        burnedAmount = AttoDecimal.div(amount, price_).ceil();
        uint256 balance = balanceOf(account);
        require(burnedAmount > 0, "Too small unstaking amount");
        require(balance >= burnedAmount, "Not enough synthetic tokens");
        uint256 remainingSyntheticBalance = balance.sub(burnedAmount);
        uint256 remainingStake = _price.mul(remainingSyntheticBalance).floor();
        if (remainingStake < 10**18) {
            burnedAmount = balance;
            unstakedAmount = unstakedAmount.add(remainingStake);
        }
    }

    function _unlockRewardsAndStake() internal {
        (uint256 unlocked, bool currentStrategyEnded) = getUnlockedRewards();
        if (currentStrategyEnded) {
            _currentStrategy = _nextStrategy;
            emit NextStrategyRemoved();
            if (_currentStrategy.endBlockNumber != 0) {
                emit CurrentStrategyUpdated(
                    _currentStrategy.perBlockReward,
                    _currentStrategy.startBlockNumber,
                    _currentStrategy.endBlockNumber
                );
            }
            delete _nextStrategy;
        }
        unlocked = Math.min(unlocked, _lockedRewards);
        if (unlocked > 0) {
            emit RewardsUnlocked(unlocked);
            _lockedRewards = _lockedRewards.sub(unlocked);
            _totalStaked = _totalStaked.add(unlocked);
        }
        lastUpdateBlockNumber = getBlockNumber();
    }

    function _update() internal {
        if (getBlockNumber() <= lastUpdateBlockNumber) return;
        _unlockRewardsAndStake();
        _updatePrice();
    }

    function _updatePrice() internal {
        uint256 totalStaked_ = _totalStaked;
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) _price = _defaultPrice;
        else _price = AttoDecimal.div(totalStaked_, totalSupply_);
        emit PriceUpdated(_price.mantissa, AttoDecimal.BASE, AttoDecimal.EXPONENTIATION);
    }

    function _validateStrategyParameters(
        uint256 perBlockReward,
        uint256 startBlockNumber,
        uint256 duration
    ) internal view {
        require(duration > 0, "Duration is zero");
        require(startBlockNumber >= getBlockNumber(), "Start block number lt current");
        require(perBlockReward <= 188 * 10**18, "Per block reward overflow");
    }

    function _setClaimingFeePercent(uint256 feePercent) internal {
        require(feePercent >= 0 && feePercent <= 100, "Invalid fee percent");
        claimingFeePercent = feePercent;
        emit ClaimingFeePercentUpdated(feePercent);
    }

    function _setUnstakingTime(uint256 unstakingTime_) internal {
        _unstakingTime = unstakingTime_;
        emit UnstakingTimeUpdated(unstakingTime_);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        _update();
        string memory errorText = "Minimal stake balance should be more or equal to 1 token";
        if (from != address(0)) {
            uint256 fromNewBalance = _price.mul(balanceOf(from).sub(amount)).floor();
            require(fromNewBalance >= MIN_STAKE_BALANCE || fromNewBalance == 0, errorText);
        }
        if (to != address(0)) {
            require(_price.mul(balanceOf(to).add(amount)).floor() >= MIN_STAKE_BALANCE, errorText);
        }
    }

    function _setCurrentStrategy(
        uint256 perBlockReward_,
        uint256 startBlockNumber_,
        uint256 endBlockNumber_
    ) private {
        _currentStrategy = Strategy({
            perBlockReward: perBlockReward_,
            startBlockNumber: startBlockNumber_,
            endBlockNumber: endBlockNumber_
        });
        emit CurrentStrategyUpdated(perBlockReward_, startBlockNumber_, endBlockNumber_);
    }

    function _stake(
        address staker,
        address payer,
        uint256 amount
    ) private returns (uint256 mintedAmount) {
        _update();
        mintedAmount = AttoDecimal.div(amount, _price).floor();
        require(mintedAmount > 0, "Too small staking amount");
        _mint(staker, mintedAmount);
        _totalStaked = _totalStaked.add(amount);
        emit Staked(staker, payer, amount, mintedAmount);
        _stakingToken.safeTransferFrom(payer, address(this), amount);
    }

    modifier onlyPositiveAmount(uint256 amount) {
        require(amount > 0, "Amount is not positive");
        _;
    }
}