pragma solidity =0.7.6;
 pragma abicoder v2;
// SPDX-License-Identifier: Cilization

import '@uniswap/v3-periphery/contracts/interfaces/IV3Migrator.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';


import './interfaces/ICivInvestment.sol';
import './interfaces/ICivHolding.sol';

/// @title CivInvestment Contract
/// @notice Add liquidity to Uniswap v3 using CivInvestment Contract router
contract CivInvestment is ICivInvestment
{

    address public constant ETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public constant CIV = 0x67E8a2E6daC96cfd1b399083c80B341174d21954;
    uint24 public constant poolFee = 3000;

    /// @inheritdoc ICivInvestment
    address public override owner;

    INonfungiblePositionManager public immutable v3NftManager;

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    constructor(
        INonfungiblePositionManager  _v3NftManager
    ) {
        owner = msg.sender;

        v3NftManager = _v3NftManager;
    }

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

    function _createDeposit(address _owner, uint256 tokenId) internal {
        (, , address token0, address token1, , , , uint128 liquidity, , , , ) =
            v3NftManager.positions(tokenId);

        // // set the owner and data for position
        // // operator is msg.sender
        deposits[tokenId] = Deposit({owner: _owner, liquidity: liquidity, token0: token0, token1: token1});
    }
    /// @inheritdoc ICivInvestment
    function swapContractOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    // @inheritdoc ICivInvestment
    function addLiquidityV3Position(uint256 ethAmountToUse, address token0, address token1, 
                                    uint24 percentage, int24 minToken1ToToken0Swap, 
                                    int24 maxToken1ToToken0Swap) external override {

    }

    // function civTradeList(
    //     address _owner
    // ) external view returns (
    //     uint256 [] memory trades
    // ) {
    //     trades = new uint256[](v3NftManager.balanceOf(_owner));
    //     for (uint i = 0; i < trades.length; i++) {
    //         uint256 nftID = v3NftManager.tokenOfOwnerByIndex(_owner, i);

    //         trades[i] = nftID;

    //     }
    //     return trades;
    // }


    function mintNewPosition(
        uint256 amount0ToMint,
        uint256 amount1ToMint
    ) external returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    ){
        TransferHelper.safeApprove(ETH, address(v3NftManager), amount0ToMint);
        TransferHelper.safeApprove(CIV, address(v3NftManager), amount1ToMint);

        // INonfungiblePositionManager.MintParams memory params =
        //     INonfungiblePositionManager.MintParams({
        //         token0: ETH,
        //         token1: CIV,
        //         fee: poolFee,
        //         tickLower: TickMath.MIN_TICK,
        //         tickUpper: TickMath.MAX_TICK,
        //         amount0Desired: amount0ToMint,
        //         amount1Desired: amount1ToMint,
        //         amount0Min: 0,
        //         amount1Min: 0,
        //         recipient: address(this),
        //         deadline: block.timestamp
        //     });

        // (tokenId, liquidity, amount0, amount1) = v3NftManager.mint(params);

        // // Create a deposit
        // _createDeposit(msg.sender, tokenId);

        // // Remove allowance and refund in both assets.
        // if (amount0 < amount0ToMint) {
        //     TransferHelper.safeApprove(ETH, address(v3NftManager), 0);
        //     uint256 refund0 = amount0ToMint - amount0;
        //     TransferHelper.safeTransfer(ETH, msg.sender, refund0);
        // }

        // if (amount1 < amount1ToMint) {
        //     TransferHelper.safeApprove(CIV, address(v3NftManager), 0);
        //     uint256 refund1 = amount1ToMint - amount1;
        //     TransferHelper.safeTransfer(CIV, msg.sender, refund1);
        // }
    }

}