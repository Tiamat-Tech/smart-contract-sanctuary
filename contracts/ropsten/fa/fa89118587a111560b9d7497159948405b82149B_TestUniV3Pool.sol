pragma solidity >=0.8.4 <0.9.0;

import '../contracts/libraries/LiquidityAmounts.sol';
import '../contracts/libraries/TickMath.sol';

contract TestUniV3Pool {
  uint24 public fee;
  address public token0;
  address public token1;
  uint160 public sqrtPriceX96 = 1 << 96;
  int56 public desiredTwap;

  constructor(address _token0, address _token1) {
    token0 = _token0;
    token1 = _token1;
  }

  // Views

  function slot0()
    public
    returns (
      uint160 _sqrtPriceX96,
      int24 _tick,
      uint16 _observationIndex,
      uint16 _observationCardinality,
      uint16 _observationCardinalityNext,
      uint8 _feeProtocol,
      bool _locked
    )
  {
    _sqrtPriceX96 = sqrtPriceX96;
    _tick = 0;
    _observationIndex = 0;
    _observationCardinality = 0;
    _observationCardinalityNext = 0;
    _feeProtocol = 0;
    _locked = false;
  }

  function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
  {}

  function positions(bytes32 key)
    external
    view
    returns (
      uint128 _liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    )
  {}

  // Methods

  function burn(
    int24 _tickLower,
    int24 _tickUpper,
    uint128 _amount
  ) public returns (uint256 _amount0, uint256 _amount1) {
    uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
    uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);

    _amount0 = LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioAX96, sqrtPriceX96, _amount);
    _amount1 = LiquidityAmounts.getAmount0ForLiquidity(sqrtPriceX96, sqrtRatioBX96, _amount);
  }

  function mint(
    address _recipient,
    int24 _tickLower,
    int24 _tickUpper,
    uint128 _amount,
    bytes calldata _data
  ) external returns (uint256 _amount0, uint256 _amount1) {
    uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
    uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);

    _amount0 = LiquidityAmounts.getAmount0ForLiquidity(sqrtRatioAX96, sqrtPriceX96, _amount);
    _amount1 = LiquidityAmounts.getAmount0ForLiquidity(sqrtPriceX96, sqrtRatioBX96, _amount);
  }

  function collect(
    address _recipient,
    int24 _tickLower,
    int24 _tickUpper,
    uint128 _amount0Requested,
    uint128 _amount1Requested
  ) external returns (uint128 _amount0, uint128 _amount1) {}

  // Setters

  function setFee(uint24 _fee) external {
    fee = _fee;
  }

  function setToken0(address _token0) external {
    token0 = _token0;
  }

  function setToken1(address _token1) external {
    token1 = _token1;
  }

  function setSqrtPriceX96(uint160 _sqrtPriceX96) external {
    sqrtPriceX96 = _sqrtPriceX96;
  }

  function setDesiredTwap(int56 _desiredTwap) external {
    desiredTwap = _desiredTwap;
  }
}