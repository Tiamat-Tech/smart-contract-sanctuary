pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/SafeCast.sol'; 
import '../libraries/Path.sol'; 
import '../libraries/Strings.sol';
import '../libraries/HexStrings.sol'; 
import '../libraries/PoolAddress.sol'; 
import '../libraries/CallbackValidation.sol'; 
import '../libraries/TickMath.sol';
import '../libraries/BitMath.sol';
import '../libraries/FullMath.sol';
import '../libraries/SqrtPriceMath.sol';
import '../libraries/LiquidityMath.sol';

import '../interface/ISummaSwapV3SwapCallback.sol'; 
import '../interface/pool/ISummaSwapV3Pool.sol'; 
import '../interface/IQuoter.sol'; 

import '../abstract/PeripheryImmutableState.sol'; 


contract Quoter is IQuoter, ISummaSwapV3SwapCallback, PeripheryImmutableState {
    using Path for bytes;
    using SafeCast for uint256;
    using Strings for uint256;
    using HexStrings for uint256;

    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (ISummaSwapV3Pool) {
        return ISummaSwapV3Pool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    /// @inheritdoc ISummaSwapV3SwapCallback
    function summaSwapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory path
    ) external view override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        (address tokenIn, address tokenOut, uint24 fee) = path.decodeFirstPool();
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountToPay, uint256 amountReceived) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta), uint256(-amount1Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta), uint256(-amount0Delta));
        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                revert(ptr, 32)
            }
        } else {
            // if the cache has been populated, ensure that the full output amount has been received
            if (amountOutCached != 0) require(amountReceived == amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                revert(ptr, 32)
            }
        }
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(bytes memory reason) private pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length < 68) revert('Unexpected error');
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256));
    }

    /// @inheritdoc IQuoter
    function quoteExactInputSingle(
        address quoteAddress,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) public override returns (uint256 amountOut) {
        bool zeroForOne = tokenIn < tokenOut;

        try
            getPool(tokenIn, tokenOut, fee).swap(
                quoteAddress, // address(0) might cause issues with some tokens
                zeroForOne,
                amountIn.toInt256(),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encodePacked(tokenIn, fee, tokenOut)
            )
        {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    function getSlot0(address tokenIn,
        address tokenOut,
        uint24 fee) public view returns(uint160 sqrtPriceX96,int24 tick,uint128  liquidity,int24 tickSpacing){
            (sqrtPriceX96,tick,,,,,) = getPool(tokenIn, tokenOut, fee).slot0();
            liquidity =  getPool(tokenIn, tokenOut, fee).liquidity();
            tickSpacing = getPool(tokenIn, tokenOut, fee).tickSpacing();

    }
    function getBitmap(address tokenIn,
        address tokenOut,
        uint24 fee,int24 tick,int24 tickSpacing) public view returns(uint256 tickBitmap){
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--;
        if(tokenIn < tokenOut){
            (int16 wordPos, uint8 bitPos) = position(compressed);
            tickBitmap = getPool(tokenIn, tokenOut, fee).tickBitmap(wordPos);
        }else{
             (int16 wordPos, uint8 bitPos) = position(compressed + 1);
             tickBitmap = getPool(tokenIn, tokenOut, fee).tickBitmap(wordPos);
        }

    }
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(tick % 256);
    }
    function getNextTick(int24 tick,int24 tickSpacing,uint256 tickBitmap,address tokenIn,address tokenOut) public view returns (int24 next, bool initialized){
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

        if (tokenIn < tokenOut) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // all the 1s at or to the right of the current bitPos
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = tickBitmap & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed - int24(bitPos - BitMath.mostSignificantBit(masked))) * tickSpacing
                : (compressed - int24(bitPos)) * tickSpacing;
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // all the 1s at or to the left of the bitPos
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = tickBitmap & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed + 1 + int24(BitMath.leastSignificantBit(masked) - bitPos)) * tickSpacing
                : (compressed + 1 + int24(type(uint8).max - bitPos)) * tickSpacing;
        }
        if (next < TickMath.MIN_TICK) {
                next = TickMath.MIN_TICK;
            } else if (next > TickMath.MAX_TICK) {
                next = TickMath.MAX_TICK;
            }
    }

    function getSqrtPriceX96(int24 tick) public view returns(uint160 sqrtPriceX96){
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    }
    function computeLessFeeAmount(int256 amountRemaining,uint24 feePips)public view returns(uint256 amountRemainingLessFee){
         amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
    }
    function computeLessMaxExChangeAmount(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        address token0,address token1)public view returns(uint256 amountIn){
            bool zeroForOne = token0<token1;
         amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
    }
    function getNextSqrtPriceFromInput(uint160 sqrtRatioCurrentX96, uint128 liquidity,uint256 amountRemainingLessFee,
            address token0,address token1) public view returns(uint160 sqrtRatioNextX96){
          bool zeroForOne = token0<token1;
         sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
    }
    function getFinalAmountExactIn(uint160 sqrtRatioCurrentX96,uint160 sqrtRatioNextX96,uint128 liquidity,int256 amountRemaining,address token0,address token1)
     public view returns(uint256 amountIn,uint256 amountOut,uint256 feeAmount){
       bool zeroForOne = token0<token1;
       if (zeroForOne) {
           amountIn = SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
           amountOut = SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
       } else {
           amountIn = SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
           amountOut = SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
       }
        feeAmount = uint256(amountRemaining) - amountIn;
    }
    
    function getAmountExactIn(uint160 sqrtRatioCurrentX96,uint160 sqrtRatioNextX96,uint128 liquidity,int256 amountRemaining,address token0,address token1,uint24 feePips)
     public view returns(uint256 amountIn,uint256 amountOut,uint256 feeAmount){
       bool zeroForOne = token0<token1;
       if (zeroForOne) {
           amountIn = SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
           amountOut = SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
       } else {
           amountIn = SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
           amountOut = SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
       }
       feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
    }
    function getSurplusAmountIn(uint256 amountIn,uint256 feeAmount,uint256 amountRemaining)
    public view returns(uint256 surplusAmount){
        surplusAmount = amountRemaining - amountIn - feeAmount;
    }
    
    function getNextTickLiquidity(int24 tickNext, bool initialized, uint128 _liquidity,address token0,address token1,uint24 fee) public view returns(int24 tick,uint128 liquidity){
         bool zeroForOne = token0<token1;
         tick = zeroForOne ? tickNext - 1 : tickNext;
         if(initialized){
             (,int128 liquidityNet,,,,,,) = getPool(token0, token1, fee).ticks(tickNext);
             if (zeroForOne) liquidityNet = -liquidityNet;
            liquidity = LiquidityMath.addDelta(_liquidity, liquidityNet);
         }
    }
    function tokenToColorHex(address token, uint256 offset) public view returns (string memory str) {
        return string((uint256(token) >> offset).toHexStringNoPrefix(3));
    }
    function computeOutMaxExChangeAmount(
         uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        address token0,address token1)public view returns(uint256 amountOut){
            bool zeroForOne = token0<token1;
         amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);
    }
     function getNextSqrtPriceFromOutput(uint160 sqrtRatioCurrentX96, uint128 liquidity,uint256 amountOut,
            address token0,address token1) public view returns(uint160 sqrtRatioNextX96){
          bool zeroForOne = token0<token1;
        sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountOut,
                    zeroForOne
                );
    }
    function getFinalAmountExactOut(uint160 sqrtRatioCurrentX96,uint160 sqrtRatioNextX96,uint128 liquidity,uint256 amountRemaining,uint24 feePips,address token0,address token1)
     public view returns(uint256 amountIn,uint256 amountOut,uint256 feeAmount){
       bool zeroForOne = token0<token1;
       if (zeroForOne) {
            amountIn = SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // cap the output amount to not exceed the remaining output amount
        if (amountOut > amountRemaining) {
            amountOut = amountRemaining;
        }
        feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        amountIn = amountIn +feeAmount;
    }
    function getAmountExactOut(uint160 sqrtRatioCurrentX96,uint160 sqrtRatioNextX96,uint128 liquidity,uint256 amountRemaining,uint24 feePips,address token0,address token1)
     public view returns(uint256 amountIn,uint256 amountOut,uint256 feeAmount){
          bool zeroForOne = token0<token1;
        if (zeroForOne) {
            amountIn = SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }
        feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        amountIn = amountIn +feeAmount;
    }
    function getSurplusAmountOut(uint256 amountOut,uint256 amountRemaining)
    public view returns(uint256 surplusAmount){
        surplusAmount = amountRemaining - amountOut;
    }    
    function add(uint256 a,uint256 b)
    public view returns(uint256 c){
        c = a + b;
    }
    function sub(uint256 a,uint256 b)
    public view returns(uint256 c){
        c = a - b;
    }    
    /// @inheritdoc IQuoter
    function quoteExactInput(address quoteAddress,bytes memory path, uint256 amountIn) external override returns (uint256 amountOut) {
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            (address tokenIn, address tokenOut, uint24 fee) = path.decodeFirstPool();

            // the outputs of prior swaps become the inputs to subsequent ones
            amountIn = quoteExactInputSingle(quoteAddress,tokenIn, tokenOut, fee, amountIn, 0);

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                path = path.skipToken();
            } else {
                return amountIn;
            }
        }
    }

    /// @inheritdoc IQuoter
    function quoteExactOutputSingle(
        address quoteAddress,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) public override returns (uint256 amountIn) {
        bool zeroForOne = tokenIn < tokenOut;

        // if no price limit has been specified, cache the output amount for comparison in the swap callback
        if (sqrtPriceLimitX96 == 0) amountOutCached = amountOut;
        try
            getPool(tokenIn, tokenOut, fee).swap(
                quoteAddress, // address(0) might cause issues with some tokens
                zeroForOne,
                -amountOut.toInt256(),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encodePacked(tokenOut, fee, tokenIn)
            )
        {} catch (bytes memory reason) {
            if (sqrtPriceLimitX96 == 0) delete amountOutCached; // clear cache
            return parseRevertReason(reason);
        }
    }

    /// @inheritdoc IQuoter
    function quoteExactOutput(address quoteAddress,bytes memory path, uint256 amountOut) external override returns (uint256 amountIn) {
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            (address tokenOut, address tokenIn, uint24 fee) = path.decodeFirstPool();

            // the inputs of prior swaps become the outputs of subsequent ones
            amountOut = quoteExactOutputSingle(quoteAddress,tokenIn, tokenOut, fee, amountOut, 0);

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                path = path.skipToken();
            } else {
                return amountOut;
            }
        }
    }
}