pragma solidity =0.7.6;
 pragma abicoder v2;
// SPDX-License-Identifier: Cilization

import '@uniswap/v3-periphery/contracts/interfaces/IV3Migrator.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import "@uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


import './interfaces/ICivInvestment.sol';
import './interfaces/ICivHolding.sol';

/// @title CivInvestment Contract
/// @notice Add liquidity to Uniswap v3 using CivInvestment Contract router
contract CivInvestment is ICivInvestment, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public constant _WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public constant _CIV = 0x67E8a2E6daC96cfd1b399083c80B341174d21954;
    uint24 public constant poolFee = 3000;


    INonfungiblePositionManager public immutable v3NftManager;
    IUniswapV3Factory public immutable v3Factory;
    IWETH9 public WETH;
    IERC20 public CIV;

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    constructor(
        INonfungiblePositionManager  _v3NftManager,
        IUniswapV3Factory  _v3Factory
    ) {
        v3NftManager = _v3NftManager;
        v3Factory = _v3Factory;
        WETH = IWETH9(_WETH);
        CIV = IERC20(_CIV);
    }

    /// @dev Function for receiving V3-LP
    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // get position information
        {
        _createDeposit(operator, tokenId);
        }
        return this.onERC721Received.selector;
    }

    /// @dev Add Deposit instance to 'deposits' mapping.
    /// @param _owner owner of v3-lp(nft)
    /// @param tokenId id of nft
    function _createDeposit(address _owner, uint256 tokenId) internal {
        (, , address token0, address token1, , , , uint128 liquidity, , , , ) =
            v3NftManager.positions(tokenId);

        // // set the owner and data for position
        // // operator is msg.sender
        deposits[tokenId] = Deposit({owner: _owner, liquidity: liquidity, token0: token0, token1: token1});
    }


    // @inheritdoc ICivInvestment
    function addLiquidityV3Position(uint256 ethAmountToUse, address token0, address token1, 
                                    uint24 percentage, int24 minToken1ToToken0Swap, 
                                    int24 maxToken1ToToken0Swap) external override {

    }

    /// @dev Get opened list of Trades(Position) of accounts
    function civOpenTradeList(
        address _owner
    ) external view returns (
        TradeInfo [] memory trades
    ) {
        trades = new TradeInfo[](v3NftManager.balanceOf(_owner));
        for (uint i = 0; i < trades.length; i++) {
            uint256 nftID = v3NftManager.tokenOfOwnerByIndex(_owner, i);
            (, , address token0, address token1, , int24 tickLower, int24 tickUpper, , , , , ) =
                        v3NftManager.positions(nftID);
            // trades[i] = nftID;
            trades[i] = TradeInfo(nftID, token0, token1, tickLower, tickUpper, 0);
        }
        return trades;
    }

    function getPositionInfo() external view returns (uint160 sqrtPriceX96, int24 tick, uint256 price) {
        IUniswapV3Pool pool = IUniswapV3Pool(v3Factory.getPool(_WETH, _CIV, poolFee));
        (sqrtPriceX96, tick, , , , , ) = pool.slot0();
        price = (uint256(sqrtPriceX96).mul(uint256(sqrtPriceX96)).mul(1e18) >> (96 * 2)).div(1e18);
    }

    function getERC20HoldingBalance(address token) public view returns(uint256 balance) {
        balance = IERC20(token).balanceOf(address(this));
    }

    function _checkRange(int24 _tickSpacing, int24 _tickLower, int24 _tickUpper) internal pure {
        require(_tickLower < _tickUpper, "tickLower < tickUpper");
        require(_tickLower >= TickMath.MIN_TICK, "tickLower too low");
        require(_tickUpper <= TickMath.MAX_TICK, "tickUpper too high");
        require(_tickLower % _tickSpacing == 0, "tickLower % tickSpacing");
        require(_tickUpper % _tickSpacing == 0, "tickUpper % tickSpacing");
    }

    /// @dev Deposits liquidity in a range on the Uniswap pool.
    function _mintLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint256 civAmount
    ) external payable returns (uint256 liquidity) {

        WETH.deposit{ value: msg.value}();
        uint256 wethAmount = msg.value * 1e18;
        TransferHelper.safeTransferFrom(_CIV, msg.sender, address(this), civAmount);

        IUniswapV3Pool pool = IUniswapV3Pool(v3Factory.getPool(_WETH, _CIV, poolFee));
        require(address(pool) != address(0), "Pool doesn't exist");

        _checkRange(pool.tickSpacing(), tickLower, tickUpper);

        TransferHelper.safeApprove(_WETH, address(pool), wethAmount);
        TransferHelper.safeApprove(_CIV, address(pool), civAmount);

        liquidity = liquidity.add(
            _liquidityForAmounts(pool, tickLower, tickUpper, msg.value * 1e18, civAmount)
        );
        emit NewLogUint256(liquidity, "liquidity");

        require(liquidity > 0, "Need liquidity");

        pool.mint(address(this), tickLower, tickUpper, _toUint128(liquidity), "");
    }

    /// @notice Collects the fees associated with provided liquidity
    /// @dev The contract must hold the erc721 token before it can collect fees
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collectAllFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        // Caller must own the ERC721 position
        // Call to safeTransfer will trigger `onERC721Received` which must return the selector else transfer will fail
        v3NftManager.safeTransferFrom(msg.sender, address(this), tokenId);

        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams memory params =
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = v3NftManager.collect(params);

        // send collected feed back to owner
        _sendToOwner(tokenId, amount0, amount1);
    }

    /// @notice Transfers funds to owner of NFT
    /// @param tokenId The id of the erc721
    /// @param amount0 The amount of token0
    /// @param amount1 The amount of token1
    function _sendToOwner(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // get owner of contract
        address _owner = deposits[tokenId].owner;

        address token0 = deposits[tokenId].token0;
        address token1 = deposits[tokenId].token1;
        // send collected fees to _owner
        TransferHelper.safeTransfer(token0, _owner, amount0);
        TransferHelper.safeTransfer(token1, _owner, amount1);
    }

    /// @notice Increases liquidity in the current range
    /// @dev Pool must be initialized already to add liquidity
    /// @param tokenId The id of the erc721 token
    /// @param amount0 The amount to add of token0
    /// @param amount1 The amount to add of token1
    function increaseLiquidityCurrentRange(
        uint256 tokenId,
        uint256 amountAdd0,
        uint256 amountAdd1
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amountAdd0,
                amount1Desired: amountAdd1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (liquidity, amount0, amount1) = v3NftManager.increaseLiquidity(params);
    }

    /// @notice A function that decreases the current liquidity by half. An example to show how to call the `decreaseLiquidity` function defined in periphery.
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount received back in token0
    /// @return amount1 The amount returned back in token1
    function decreaseLiquidityInHalf(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        // caller must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, 'Not the owner');
        // get liquidity data for tokenId
        uint128 liquidity = deposits[tokenId].liquidity;
        uint128 halfLiquidity = liquidity / 2;

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: halfLiquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = v3NftManager.decreaseLiquidity(params);

        //send liquidity back to owner
        _sendToOwner(tokenId, amount0, amount1);
    }

    /// @dev Wrapper around `LiquidityAmounts.getLiquidityForAmounts()`.
    function _liquidityForAmounts(
        IUniswapV3Pool pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        return
        LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            amount0,
            amount1
        );
    }

    /// @dev Casts uint256 to uint128 with overflow check.
    function _toUint128(uint256 x) internal pure returns (uint128) {
        assert(x <= type(uint128).max);
        return uint128(x);
    }

}