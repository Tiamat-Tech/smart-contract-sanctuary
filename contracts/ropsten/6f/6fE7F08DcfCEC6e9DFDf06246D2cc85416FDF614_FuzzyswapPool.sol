// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IFuzzyswapPool.sol';
import './interfaces/IExternalOracle.sol';
import './interfaces/IFuzzyswapVirtualPool.sol';

// LICENSED

//import './libraries/Oracle.sol';
import './libraries/Position.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/SwapMath.sol';
import './libraries/Tick.sol';
import './libraries/TickTable.sol';

// UNLICENSED

import './libraries/LowGasSafeMath.sol';
import './libraries/SafeCast.sol';

import './libraries/FullMath.sol';
import './libraries/Constants.sol';
import './libraries/TransferHelper.sol';
import './libraries/TickMath.sol';
import './libraries/LiquidityMath.sol';

import './interfaces/IFuzzyswapPoolDeployer.sol';
import './interfaces/IFuzzyswapFactory.sol';
import './interfaces/IERC20Minimal.sol';
import './interfaces/callback/IFuzzyswapMintCallback.sol';
import './interfaces/callback/IFuzzyswapSwapCallback.sol';
import './interfaces/callback/IFuzzyswapFlashCallback.sol';

contract FuzzyswapPool is IFuzzyswapPool {
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using TickTable for mapping(int16 => uint256);
    using Tick for mapping(int24 => Tick.Data);
    using Position for Position.Data;
    using Position for mapping(bytes32 => Position.Data);

    IExternalOracle public immutable override externalOracle;
    /// @inheritdoc IFuzzyswapPoolImmutables
    address public immutable override factory;
    /// @inheritdoc IFuzzyswapPoolImmutables
    address public immutable override token0;
    /// @inheritdoc IFuzzyswapPoolImmutables
    address public immutable override token1;
    uint24 public override fee;
    uint24 private constant fee_ = 500;

    /// @inheritdoc IFuzzyswapPoolImmutables
    uint8 public constant override tickSpacing = 60;
    
    /// @inheritdoc IFuzzyswapPoolImmutables
    uint128 public constant override maxLiquidityPerTick = 11505743598341114571880798222544994;

    struct GlobalState {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the most-recently updated index of the observations written on swap
        uint16 observationIndexSwap;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    /// @inheritdoc IFuzzyswapPoolState
    uint256 public override totalFeeGrowth0Token;
    /// @inheritdoc IFuzzyswapPoolState
    uint256 public override totalFeeGrowth1Token;
    /// @inheritdoc IFuzzyswapPoolState
    GlobalState public override globalState;

    // accumulated protocol fees in token0/token1 units
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }
    /// @inheritdoc IFuzzyswapPoolState
    ProtocolFees public override protocolFees;

    /// @inheritdoc IFuzzyswapPoolState
    uint128 public override liquidity;

    /// @inheritdoc IFuzzyswapPoolState
    mapping(int24 => Tick.Data) public override ticks;
    /// @inheritdoc IFuzzyswapPoolState
    mapping(int16 => uint256) public override tickTable;
    /// @inheritdoc IFuzzyswapPoolState
    mapping(bytes32 => Position.Data) public override positions;

    struct Incentive {
        address virtualPool;
        uint32 endTimestamp;
        uint32 startTimestamp;
    }

    Incentive public activeIncentive;

    /// @dev Mutually exclusive reentrancy protection into the pool to/from a method. This method also prevents entrance
    /// to a function before the pool is initialized. The reentrancy guard is required throughout the contract because
    /// we use balance checks to determine the payment status of interactions such as mint, swap and flash.
    modifier lock() {
        require(globalState.unlocked, 'LOK');
        globalState.unlocked = false;
        _;
        globalState.unlocked = true;
    }

    /// @dev Prevents calling a function from anyone except the address returned by IFuzzyswapFactory#owner()
    modifier onlyFactoryOwner() {
        require(msg.sender == IFuzzyswapFactory(factory).owner());
        _;
    }

    constructor() {
        address _externalOracle;
        (_externalOracle, factory, token0, token1) = IFuzzyswapPoolDeployer(msg.sender).parameters();
        externalOracle = IExternalOracle(_externalOracle);
        fee = fee_;
    }

    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balanceToken0() private view returns (uint256) {
        (bool success, bytes memory data) =
            token0.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get the pool's balance of token1
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check
    function balanceToken1() private view returns (uint256) {
        (bool success, bytes memory data) =
            token1.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function observations(uint256 index)
        external
        override
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulative,
            uint112 volatilityCumulative,
            bool initialized,
            uint256 volumePerAvgLiquidity
        ){
        return externalOracle.observations(index);
    }

    /// @dev Common checks for valid tick inputs.
    function tickValidation(int24 bottomTick, int24 topTick) private pure {
        require(bottomTick < topTick, 'TLU');
        require(bottomTick >= TickMath.MIN_TICK, 'TLM');
        require(topTick <= TickMath.MAX_TICK, 'TUM');
    }

    /// @dev Returns the block timestamp truncated to 32 bits, i.e. mod 2**32. This method is overridden in tests.
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // truncation is desired
    }

    struct cumulatives{
        int56 tickCumulative;
        uint160 outerSecondPerLiquidity;
        uint32 outerSecondsSpent;
    }

    /// @inheritdoc IFuzzyswapPoolDerivedState
    function getInnerCumulatives(int24 bottomTick, int24 topTick)
        external
        view
        override
        returns (
            int56 innerTickCumulative,
            uint160 innerSecondsSpentPerLiquidity,
            uint32 innerSecondsSpent
        )
    {
        tickValidation(bottomTick, topTick);

        cumulatives memory upper;
        cumulatives memory lower;

        {
            Tick.Data storage _lower = ticks[bottomTick];
            Tick.Data storage _upper = ticks[topTick];
            (
                lower.tickCumulative,
                lower.outerSecondPerLiquidity,
                lower.outerSecondsSpent
            ) = (
                _lower.outerTickCumulative,
                _lower.outerSecondsPerLiquidity,
                _lower.outerSecondsSpent
            );

            (
                upper.tickCumulative,
                upper.outerSecondPerLiquidity,
                upper.outerSecondsSpent
            ) = (
                _upper.outerTickCumulative,
                _upper.outerSecondsPerLiquidity,
                _upper.outerSecondsSpent
            );
            require(_lower.initialized);
            require(_upper.initialized);
        }

        GlobalState memory _globalState = globalState;

        if (_globalState.tick < bottomTick) {
            return (
                lower.tickCumulative - upper.tickCumulative,
                lower.outerSecondPerLiquidity - upper.outerSecondPerLiquidity,
                lower.outerSecondsSpent - upper.outerSecondsSpent
            );
        } else if (_globalState.tick < topTick) {
            uint32 globalTime = _blockTimestamp();
            (int56 globalTickCumulative, uint160 globalSecondsPerLiquidityCumulative,,) =
                externalOracle.observeSingle(
                    globalTime,
                    0,
                    _globalState.tick,
                    _globalState.observationIndex,
                    liquidity
                );
            return (
                globalTickCumulative -
                    lower.tickCumulative -
                    upper.tickCumulative,
                globalSecondsPerLiquidityCumulative -
                    lower.outerSecondPerLiquidity -
                    upper.outerSecondPerLiquidity,
                globalTime -
                lower.outerSecondsSpent -
                upper.outerSecondsSpent
            );
        } else {
            return (
                upper.tickCumulative - lower.tickCumulative,
                upper.outerSecondPerLiquidity - lower.outerSecondPerLiquidity,
                upper.outerSecondsSpent - lower.outerSecondsSpent
            );
        }
    }

    /// @inheritdoc IFuzzyswapPoolDerivedState
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives,
                uint160[] memory secondsPerLiquidityCumulatives,
                uint112[] memory volatilityCumulatives,
                uint256[] memory volumePerAvgLiquiditys)
    {
        return
            externalOracle.observe(
                _blockTimestamp(),
                secondsAgos,
                globalState.tick,
                globalState.observationIndex,
                liquidity
            );
    }

    /// @inheritdoc IFuzzyswapPoolActions
    /// @dev not locked because it initializes unlocked
    function initialize(uint160 sqrtPriceX96) external override {
        require(globalState.sqrtPriceX96 == 0);

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        externalOracle.initialize(_blockTimestamp());

        globalState = GlobalState({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationIndexSwap: 0,
            feeProtocol: 0,
            unlocked: true
        });

        emit Initialize(sqrtPriceX96, tick);
    }

    struct ModifyPositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper tick of the position
        int24 bottomTick;
        int24 topTick;
        // any change in liquidity
        int128 liquidityDelta;
    }

    /// @dev Effect some changes to a position
    /// @param params the position details and the change to the position's liquidity to effect
    /// @return position a storage pointer referencing the position with the given owner and tick range
    /// @return amount0 the amount of token0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount1 the amount of token1 owed to the pool, negative if the pool should pay the recipient
    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (
            Position.Data storage position,
            int256 amount0,
            int256 amount1
        )
    {

        GlobalState memory _globalState = globalState; // SLOAD for gas optimization

        position = _applyLiquidityDeltaToPosition(
            params.owner,
            params.bottomTick,
            params.topTick,
            params.liquidityDelta,
            _globalState.tick
        );

        if (params.liquidityDelta != 0) {
             int128 globalLiquidityDelta;
            (amount0, amount1, globalLiquidityDelta) = _getAmountsForLiquidity(
                params.bottomTick, 
                params.topTick,
                params.liquidityDelta,
                _globalState);
            if (globalLiquidityDelta != 0) {
                uint128 liquidityBefore = liquidity; // SLOAD for gas optimization
                    globalState.observationIndex = externalOracle.write(
                    _globalState.observationIndex,
                    _blockTimestamp(),
                    _globalState.tick,
                    liquidityBefore,
                    0,
                    0
                );

                _changeFee(_blockTimestamp(), _globalState.tick, globalState.observationIndex, liquidityBefore);
                liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            }
        }
    }

    function _getAmountsForLiquidity (
        int24 bottomTick,
        int24 topTick,
        int128 liquidityDelta,
        GlobalState memory _globalState) 
    private pure
    returns(int256 amount0, int256 amount1, int128 globalLiquidityDelta) {
            if (_globalState.tick < bottomTick) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(bottomTick),
                    TickMath.getSqrtRatioAtTick(topTick),
                    liquidityDelta
                );
            } else if (_globalState.tick < topTick) {
                // current tick is inside the passed range

                amount0 = SqrtPriceMath.getAmount0Delta(
                    _globalState.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(topTick),
                    liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(bottomTick),
                    _globalState.sqrtPriceX96,
                    liquidityDelta
                );

                globalLiquidityDelta = liquidityDelta;
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(bottomTick),
                    TickMath.getSqrtRatioAtTick(topTick),
                    liquidityDelta
                );
            }
    }

    /// @notice Returns the Info struct of a position, given an owner and position boundaries
    /// @param owner The address of the position owner
    /// @param bottomTick The lower tick boundary of the position
    /// @param topTick The upper tick boundary of the position
    /// @return position The position info struct of the given owners' position
    function getOrCreatePosition(
        address owner,
        int24 bottomTick,
        int24 topTick
    ) private view returns (Position.Data storage) {
        bytes32 key;
        assembly {
            let p := mload(0x40)
            mstore(0x40, add(p, 96))
            mstore(p, topTick)
            mstore(add(p, 32), bottomTick)
            mstore(add(p, 64), owner)
            key := keccak256(p, 96)
        }
        return positions[key];
    }

    /// @dev Gets and updates a position with the given liquidity delta
    /// @param owner the owner of the position
    /// @param bottomTick the lower tick of the position's tick range
    /// @param topTick the upper tick of the position's tick range
    /// @param tick the current tick, passed to avoid sloads
    function _applyLiquidityDeltaToPosition(
        address owner,
        int24 bottomTick,
        int24 topTick,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Data storage position) {
        position = getOrCreatePosition(owner, bottomTick, topTick);

        // SLOAD for gas optimization
        (uint256 _totalFeeGrowth0Token, uint256 _totalFeeGrowth1Token) = (totalFeeGrowth0Token, totalFeeGrowth1Token);

        // if we need to update the ticks, do it
        bool flippedBottom;
        bool flippedTop;
        if (liquidityDelta != 0) {
            uint32 time = _blockTimestamp();
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulative,,) =
                externalOracle.observeSingle(
                    time,
                    0,
                    globalState.tick,
                    globalState.observationIndex,
                    liquidity
                );

            if (ticks.update(
                bottomTick,
                tick,
                liquidityDelta,
                _totalFeeGrowth0Token,
                _totalFeeGrowth1Token,
                secondsPerLiquidityCumulative,
                tickCumulative,
                time,
                false
            )) {
                flippedBottom = true;
                tickTable.flipTick(bottomTick);
            }

            if (ticks.update(
                topTick,
                tick,
                liquidityDelta,
                _totalFeeGrowth0Token,
                _totalFeeGrowth1Token,
                secondsPerLiquidityCumulative,
                tickCumulative,
                time,
                true
            )) {
                flippedTop = true;
                tickTable.flipTick(topTick);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getInnerFeeGrowth(bottomTick, topTick, tick, _totalFeeGrowth0Token, _totalFeeGrowth1Token);

        position.recalculate(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedBottom) {
                ticks.clear(bottomTick);
            }
            if (flippedTop) {
                ticks.clear(topTick);
            }
        }
    }

    /// @inheritdoc IFuzzyswapPoolActions
    function mint(
        address sender,
        address recipient,
        int24 bottomTick,
        int24 topTick,
        uint128 _liquidity,
        bytes calldata data
    ) external override lock returns (uint256 amount0, uint256 amount1, uint256 liquidityAmount) {
       require(_liquidity > 0, 'IL');
       tickValidation(bottomTick, topTick);
        {
            (int256 amount0Int, int256 amount1Int, ) = _getAmountsForLiquidity(
                bottomTick, 
                topTick,  
                int256(_liquidity).toInt128(),
                globalState
            );

            amount0 = uint256(amount0Int);
            amount1 = uint256(amount1Int);
        }

        uint256 realAmount0;
        uint256 realAmount1;
        {
            if (amount0 > 0) realAmount0 = balanceToken0();
            if (amount1 > 0) realAmount1 = balanceToken1();
            IFuzzyswapMintCallback(msg.sender).fuzzyswapMintCallback(amount0, amount1, data);
            if (amount0 > 0) require((realAmount0 = balanceToken0() - realAmount0) > 0, 'IIAM');
            if (amount1 > 0) require((realAmount1 = balanceToken1() - realAmount1) > 0, 'IIAM');
        }

        if (realAmount0 < amount0) {
            _liquidity = uint128(FullMath.mulDiv(uint256(_liquidity), realAmount0, amount0));
            
        } 
        if (realAmount1 < amount1) {
            uint128 liquidityForRA1 = uint128(FullMath.mulDiv(uint256(_liquidity), realAmount1, amount1));
            if (liquidityForRA1 < _liquidity) {
                _liquidity = liquidityForRA1;
            }
        }

        require(_liquidity > 0, 'IIL2');

        {
            (, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    bottomTick: bottomTick,
                    topTick: topTick,
                    liquidityDelta: int256(_liquidity).toInt128()
                })
            );

            require((amount0 = uint256(amount0Int)) <= realAmount0, 'IIAM2');
            require((amount1 = uint256(amount1Int)) <= realAmount1, 'IIAM2');
        }

        if (realAmount0 > amount0) {
            TransferHelper.safeTransfer(token0, sender, realAmount0 - amount0);
        }
        if (realAmount1 > amount1) {
            TransferHelper.safeTransfer(token1, sender, realAmount1 - amount1);
        }
        liquidityAmount = _liquidity;
        emit Mint(msg.sender, recipient, bottomTick, topTick, _liquidity, amount0, amount1);
    }

    /// @inheritdoc IFuzzyswapPoolActions
    function collect(
        address recipient,
        int24 bottomTick,
        int24 topTick,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        // we don't need to checkTicks here, because invalid positions will never have non-zero fees{0,1}
        Position.Data storage position = getOrCreatePosition(msg.sender, bottomTick, topTick);

        amount0 = amount0Requested > position.fees0 ? position.fees0 : amount0Requested;
        amount1 = amount1Requested > position.fees1 ? position.fees1 : amount1Requested;

        if (amount0 > 0) {
            position.fees0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            position.fees1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit Collect(msg.sender, recipient, bottomTick, topTick, amount0, amount1);
    }

    /// @inheritdoc IFuzzyswapPoolActions
    function burn(
        int24 bottomTick,
        int24 topTick,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        tickValidation(bottomTick, topTick);
        (Position.Data storage position, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    bottomTick: bottomTick,
                    topTick: topTick,
                    liquidityDelta: -int256(amount).toInt128()
                })
            );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.fees0, position.fees1) = (
                position.fees0 + uint128(amount0),
                position.fees1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, bottomTick, topTick, amount, amount0, amount1);
    }

    /// @dev Changes fee according to k*TWAV+b
    function _changeFee(
        uint32 _time,
        int24 _tick,
        uint16 _index,
        uint128 _liquidity
    ) private {
        fee = externalOracle.getFee(
            _time,
            _tick,
            _index,
            _liquidity
        );
        //fee = uint24(49 * TWVolatilityAverage + fee_) <= 15000 ? uint24(49 * TWVolatilityAverage + fee_) : 15000;
    }

    struct SwapCache {
        // the protocol fee for the input token
        uint8 feeProtocol;
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // the timestamp of the current block
        uint32 blockTimestamp;
        // the current value of the tick accumulator, computed only if we cross an initialized tick
        int56 tickCumulative;
        // the current value of seconds per liquidity accumulator, computed only if we cross an initialized tick
        uint160 secondsPerLiquidityCumulative;
        // whether we've computed and cached the above two accumulators
        bool computedLatestObservation;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // amount of input token paid as protocol fee
        uint128 protocolFee;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    /// @inheritdoc IFuzzyswapPoolActions
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        SwapCache memory cache;
        SwapState memory state;

        (amount0, amount1, cache, state) = _calculateSwap(
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96
        );
        // do the transfers and collect payment
        if (zeroForOne) {
            if (amount1 < 0) TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));

            uint256 balance0Before = balanceToken0();
            IFuzzyswapSwapCallback(msg.sender).fuzzyswapSwapCallback(amount0, amount1, data);
            require(balance0Before.add(uint256(amount0)) <= balanceToken0(), 'IIA');
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

            uint256 balance1Before = balanceToken1();
            IFuzzyswapSwapCallback(msg.sender).fuzzyswapSwapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balanceToken1(), 'IIA');
        }


        _changeFee(cache.blockTimestamp, state.tick, globalState.observationIndex, liquidity);

        emit Swap(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.tick);
        globalState.unlocked = true;
    }

    function swapSupportingFeeOnInputTokens(
        address sender,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override returns (int256 amount0, int256 amount1) {
        SwapCache memory cache;
        SwapState memory state;

        if (zeroForOne) {
            uint256 balance0Before = balanceToken0();
            IFuzzyswapSwapCallback(msg.sender).fuzzyswapSwapCallback(amountSpecified, 0, data);
            require((amountSpecified = int(balanceToken0().sub(balance0Before))) > 0, 'IIA');
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

            uint256 balance1Before = balanceToken1();
            IFuzzyswapSwapCallback(msg.sender).fuzzyswapSwapCallback(0, amountSpecified, data);
            require((amountSpecified = int(balanceToken1().sub(balance1Before))) > 0, 'IIA');
        }

        (amount0, amount1, cache, state) = _calculateSwap(
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96
        );
        // do the transfers and collect payment

        
        if (zeroForOne) {
            if (amount1 < 0) TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));

            if (amount0 < amountSpecified) {
                TransferHelper.safeTransfer(token0, sender, uint256(amountSpecified.sub(amount0)));
            }
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

            if (amount1 < amountSpecified) {
                TransferHelper.safeTransfer(token1, sender, uint256(amountSpecified.sub(amount1)));
            }
        }


        _changeFee(cache.blockTimestamp, state.tick, globalState.observationIndex, liquidity);

        emit Swap(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.tick);
        globalState.unlocked = true;
    }

    function _calculateSwap(        
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
        ) private returns(int256 amount0, int256 amount1, SwapCache memory cache, SwapState memory state) {
        require(amountSpecified != 0, 'AS');

        GlobalState memory globalStateStart = globalState;

        require(globalStateStart.unlocked, 'LOK');
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < globalStateStart.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > globalStateStart.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            'SPL'
        );

        globalState.unlocked = false;

        cache =
            SwapCache({
                liquidityStart: liquidity,
                blockTimestamp: _blockTimestamp(),
                feeProtocol: zeroForOne ? (globalStateStart.feeProtocol % 16) : (globalStateStart.feeProtocol >> 4),
                secondsPerLiquidityCumulative: 0,
                tickCumulative: 0,
                computedLatestObservation: false
            });

        bool exactInput = amountSpecified > 0;

        state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: globalStateStart.sqrtPriceX96,
                tick: globalStateStart.tick,
                feeGrowthGlobalX128: zeroForOne ? totalFeeGrowth0Token : totalFeeGrowth1Token,
                protocolFee: 0,
                liquidity: cache.liquidityStart
            });

        uint32 _time;
        if(activeIncentive.virtualPool != address(0)){
            (_time,,,,,) = externalOracle.observations(globalStateStart.observationIndexSwap);
            if (_time != cache.blockTimestamp){
                if(activeIncentive.endTimestamp > cache.blockTimestamp){
                    IFuzzyswapVirtualPool(activeIncentive.virtualPool).increaseCumulative(
                        _time,
                        cache.blockTimestamp
                    );
                }
            }
        }

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickTable.nextTickInTheSameRow(
                state.tick,
                zeroForOne
            );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                zeroForOne,
                state.sqrtPriceX96,
                (!zeroForOne != (step.sqrtPriceNextX96 < sqrtPriceLimitX96))
                        ? sqrtPriceLimitX96
                        : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (cache.feeProtocol > 0) {
                uint256 delta = step.feeAmount / cache.feeProtocol;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            // update global fee tracker
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, Constants.Q128, state.liquidity);

            // shift tick if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    if (!cache.computedLatestObservation) {
                        (cache.tickCumulative, cache.secondsPerLiquidityCumulative,,) = externalOracle.observeSingle(
                            cache.blockTimestamp,
                            0,
                            globalStateStart.tick,
                            globalStateStart.observationIndex,
                            cache.liquidityStart
                        );
                        cache.computedLatestObservation = true;
                    }
                    if(activeIncentive.virtualPool != address(0)){
                        if(activeIncentive.endTimestamp > cache.blockTimestamp){
                            IFuzzyswapVirtualPool(activeIncentive.virtualPool).cross(
                                step.tickNext,
                                zeroForOne
                            );
                        }
                    }
                    int128 liquidityDelta =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : totalFeeGrowth0Token),
                            (zeroForOne ? totalFeeGrowth1Token : state.feeGrowthGlobalX128),
                            cache.secondsPerLiquidityCumulative,
                            cache.tickCumulative,
                            cache.blockTimestamp
                        );
                    // if we're moving leftward, we interpret liquidityDelta as the opposite sign
                    // safe because liquidityDelta cannot be type(int128).min
                    if (zeroForOne) liquidityDelta = -liquidityDelta;

                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityDelta);
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved

                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
                if(activeIncentive.endTimestamp > cache.blockTimestamp){
                        IFuzzyswapVirtualPool(activeIncentive.virtualPool).cross(
                            state.tick,
                            zeroForOne
                        );
                }
            }
        }

        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        // update tick and write an oracle entry if the tick change
        if (state.tick != globalStateStart.tick) {
            uint16 observationIndex =
                externalOracle.write(
                    globalStateStart.observationIndex,
                    cache.blockTimestamp,
                    globalStateStart.tick,
                    cache.liquidityStart,
                    amount0,
                    amount1
                );
            (globalState.sqrtPriceX96, globalState.tick, globalState.observationIndex, globalState.observationIndexSwap) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationIndex
            );
            if(activeIncentive.virtualPool != address(0)){
                 if (activeIncentive.startTimestamp <= cache.blockTimestamp){
                    if(activeIncentive.endTimestamp < cache.blockTimestamp){
                        activeIncentive.endTimestamp = 0;
                        activeIncentive.virtualPool = address(0);
                    }
                    else{
                        IFuzzyswapVirtualPool(activeIncentive.virtualPool).processSwap(
                        );
                    }
                }
            }
        } else {
            // otherwise just update the price
            globalState.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // update liquidity if it changed
        if (cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

        // update fee growth global and, if necessary, protocol fees
        // overflow is acceptable, protocol has to withdraw before it hits type(uint128).max fees
        if (zeroForOne) {
            totalFeeGrowth0Token = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
        } else {
            totalFeeGrowth1Token = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
        }


    }

    /// @inheritdoc IFuzzyswapPoolActions
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override lock {
        uint128 _liquidity = liquidity;
        require(_liquidity > 0, 'L');

        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, fee, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, fee, 1e6);
        uint256 balance0Before = balanceToken0();
        uint256 balance1Before = balanceToken1();

        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        IFuzzyswapFlashCallback(msg.sender).fuzzyswapFlashCallback(fee0, fee1, data);

        uint256 paid0 = balanceToken0();
        uint256 paid1 = balanceToken1();

        require(balance0Before.add(fee0) <= paid0, 'F0');
        require(balance1Before.add(fee1) <= paid1, 'F1');

        // sub is safe because we know balanceAfter is gt balanceBefore by at least fee
        paid0 -= balance0Before;
        paid1 -= balance1Before;

        if (paid0 > 0) {
            uint8 feeProtocol0 = globalState.feeProtocol % 16;
            uint256 fees0 = feeProtocol0 == 0 ? 0 : paid0 / feeProtocol0;
            if (uint128(fees0) > 0) protocolFees.token0 += uint128(fees0);
            totalFeeGrowth0Token += FullMath.mulDiv(paid0 - fees0, Constants.Q128, _liquidity);
        }
        if (paid1 > 0) {
            uint8 feeProtocol1 = globalState.feeProtocol >> 4;
            uint256 fees1 = feeProtocol1 == 0 ? 0 : paid1 / feeProtocol1;
            if (uint128(fees1) > 0) protocolFees.token1 += uint128(fees1);
            totalFeeGrowth1Token += FullMath.mulDiv(paid1 - fees1, Constants.Q128, _liquidity);
        }

        emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }

    /// @inheritdoc IFuzzyswapPoolOwnerActions
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override lock onlyFactoryOwner {
        require(
            (feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
                (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10))
        );
        uint8 feeProtocolOld = globalState.feeProtocol;
        globalState.feeProtocol = feeProtocol0 + (feeProtocol1 << 4);
        emit SetFeeProtocol(feeProtocolOld % 16, feeProtocolOld >> 4, feeProtocol0, feeProtocol1);
    }

    /// @inheritdoc IFuzzyswapPoolOwnerActions
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock onlyFactoryOwner returns (uint128 amount0, uint128 amount1) {
        amount0 = amount0Requested > protocolFees.token0 ? protocolFees.token0 : amount0Requested;
        amount1 = amount1Requested > protocolFees.token1 ? protocolFees.token1 : amount1Requested;

        if (amount0 > 0) {
            if (amount0 == protocolFees.token0) amount0--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            if (amount1 == protocolFees.token1) amount1--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit CollectProtocol(msg.sender, recipient, amount0, amount1);
    }

    /**
     *  @dev Sets new active incentive
     */
    function setIncentive(address virtualPoolAddress, uint32 endTimestamp, uint32 startTimestamp) external override {
        require(msg.sender == IFuzzyswapFactory(factory).stackerAddress());
        require(activeIncentive.endTimestamp < _blockTimestamp());
        activeIncentive = Incentive(virtualPoolAddress, endTimestamp, startTimestamp);
    }
}