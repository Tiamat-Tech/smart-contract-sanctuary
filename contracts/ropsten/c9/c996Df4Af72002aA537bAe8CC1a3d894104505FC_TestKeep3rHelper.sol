// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

import '../contracts/libraries/FullMath.sol';
import '../contracts/libraries/TickMath.sol';
import '../interfaces/IKeep3r.sol';
import '../interfaces/external/IKeep3rV1.sol';
import '../interfaces/IKeep3rHelper.sol';

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

interface ITestUniV3Pool {
  function desiredTwap() external view returns (int56);
}

interface ITestKeep3r {
  struct TickCache {
    int56 current; // Tracks the current tick
    int56 difference; // Stores the difference between the current tick and the last tick
    uint256 period; // Stores the period at which the last observation was made
  }

  function getTickCache(address) external view returns (TickCache memory);
}

contract TestKeep3rHelper is IKeep3rHelper {
  address public immutable keep3rV2;

  constructor(address _keep3rV2, address _kp3r) {
    keep3rV2 = _keep3rV2;
    KP3R = _kp3r;
  }

  /// @inheritdoc IKeep3rHelper
  address public override KP3R = 0x1cEB5cB57C4D4E2b2433641b95Dd330A33185A44;

  /// @inheritdoc IKeep3rHelper
  address public constant override KP3R_WETH_POOL = 0x11B7a6bc0259ed6Cf9DB8F499988F9eCc7167bf5;

  /// @inheritdoc IKeep3rHelper
  uint256 public constant override MIN = 11_000;

  /// @inheritdoc IKeep3rHelper
  uint256 public constant override MAX = 12_000;

  /// @inheritdoc IKeep3rHelper
  uint256 public constant override BOOST_BASE = 10_000;

  /// @inheritdoc IKeep3rHelper
  uint256 public constant override TARGETBOND = 200 ether;

  /// @inheritdoc IKeep3rHelper
  function quote(uint256 _eth) public view override returns (uint256 _amountOut) {
    /// @dev Payment KP3Rs will be quoted 1=1 for testing purposes
    _amountOut = _eth;
  }

  /// @inheritdoc IKeep3rHelper
  function bonds(address _keeper) public view override returns (uint256 _amountBonded) {
    return IKeep3r(keep3rV2).bonds(_keeper, KP3R);
  }

  /// @inheritdoc IKeep3rHelper
  function getRewardAmountFor(address _keeper, uint256 _gasUsed) public view override returns (uint256 _kp3r) {
    uint256 _boost = getRewardBoostFor(bonds(_keeper));
    _kp3r = quote((_gasUsed * _boost) / BOOST_BASE);
  }

  /// @inheritdoc IKeep3rHelper
  function getRewardAmount(uint256 _gasUsed) external view override returns (uint256 _amount) {
    // solhint-disable-next-line avoid-tx-origin
    return getRewardAmountFor(tx.origin, _gasUsed);
  }

  /// @inheritdoc IKeep3rHelper
  function getRewardBoostFor(uint256 _bonds) public view override returns (uint256 _rewardBoost) {
    _bonds = Math.min(_bonds, TARGETBOND);
    uint256 _cap = Math.max(MIN, MIN + ((MAX - MIN) * _bonds) / TARGETBOND);
    _rewardBoost = _cap * _getBasefee();
  }

  /// @inheritdoc IKeep3rHelper
  function getPoolTokens(address _pool) public view override returns (address _token0, address _token1) {
    return (IUniswapV3Pool(_pool).token0(), IUniswapV3Pool(_pool).token1());
  }

  /// @inheritdoc IKeep3rHelper
  function isKP3RToken0(address _pool) public view override returns (bool _isKP3RToken0) {
    address _token0;
    address _token1;
    (_token0, _token1) = getPoolTokens(_pool);
    if (_token0 == KP3R) {
      return true;
    } else if (_token1 != KP3R) {
      revert LiquidityPairInvalid();
    }
  }

  /// @inheritdoc IKeep3rHelper
  function observe(address _pool, uint32[] memory _secondsAgo)
    public
    view
    override
    returns (
      int56 _tickCumulative1,
      int56 _tickCumulative2,
      bool _success
    )
  {
    int56 _currentTick = ITestKeep3r(keep3rV2).getTickCache(_pool).current;
    uint256 _rewardPeriodTime = IKeep3r(keep3rV2).rewardPeriodTime();
    int56 _desiredTwap = ITestUniV3Pool(_pool).desiredTwap();

    if (_secondsAgo.length == 1) {
      _tickCumulative1 = _currentTick + (_desiredTwap * int56(int256(_rewardPeriodTime)));
    } else {
      _tickCumulative1 = 0;
      _tickCumulative2 = _desiredTwap * int56(int256(_rewardPeriodTime));
    }

    _success = true;
  }

  /// @inheritdoc IKeep3rHelper
  function getKP3RsAtTick(
    uint256 _liquidityAmount,
    int56 _tickDifference,
    uint256 _timeInterval
  ) public pure override returns (uint256 _kp3rAmount) {
    uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(int24(_tickDifference / int256(_timeInterval)));
    _kp3rAmount = FullMath.mulDiv(1 << 96, _liquidityAmount, sqrtRatioX96);
  }

  /// @inheritdoc IKeep3rHelper
  function getQuoteAtTick(
    uint128 _baseAmount,
    int56 _tickDifference,
    uint256 _timeInterval
  ) public pure override returns (uint256 _quoteAmount) {
    uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(int24(_tickDifference / int256(_timeInterval)));

    if (sqrtRatioX96 <= type(uint128).max) {
      uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
      _quoteAmount = FullMath.mulDiv(1 << 192, _baseAmount, ratioX192);
    } else {
      uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
      _quoteAmount = FullMath.mulDiv(1 << 128, _baseAmount, ratioX128);
    }
  }

  /// @notice Gets the block's base fee
  /// @return _baseFee The block's basefee
  function _getBasefee() internal view virtual returns (uint256 _baseFee) {
    return block.basefee;
  }
}