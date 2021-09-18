pragma solidity ^0.7.0;
 pragma abicoder v2;
// SPDX-License-Identifier: Cilization

import '@uniswap/v3-periphery/contracts/interfaces/IV3Migrator.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './interfaces/ICivInvestment.sol';
import './interfaces/ICivHolding.sol';

/// @title CivInvestment Contract
/// @notice Add liquidity to Uniswap v3 using CivInvestment Contract router
contract CivInvestment is ICivInvestment
{
    /// @inheritdoc ICivInvestment
    address public override owner;

    address public immutable factory;

    IUniswapV3Factory v3Factory;
    INonfungiblePositionManager v3Nft;
    ISwapRouter public immutable v3SwapRouter;
    uint public constant poolFee = 3000;
    
    constructor(
        address _factory,
        address _v3Nft,
        ISwapRouter _swapRouter
    ) {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        factory = _factory;
        // migrator = _migrator;
        v3Nft = INonfungiblePositionManager(_v3Nft);
        v3SwapRouter = _swapRouter;
        v3Factory = IUniswapV3Factory(_factory);
    }

    /// @inheritdoc ICivInvestment
    function swapContractOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc ICivInvestment
    function addLiquidityV3Position(uint256 ethAmountToUse, address token0, address token1, 
                                    uint24 percentage, int24 minToken1ToToken0Swap, 
                                    int24 maxToken1ToToken0Swap) external override {
        // get token0 x token1 pair from Uniswap
        address pair = v3Factory.getPool(token0, token1, percentage);
        // create pool if pair does not exist
        if (pair == address(0)) {
            pair = v3Factory.createPool(token0, token1, percentage);
        }
    }

    // function migrate(uint256 ethAmountToUse, address token0, address token1, 
    //                                 uint24 percentage, int24 minToken1ToToken0Swap, 
    //                                 int24 maxToken1ToToken0Swap) external {
    //     // get token0 x token1 pair from Uniswap
    //     address pair = v3Factory.getPool(token0, token1, percentage);
    //     // create pool if pair does not exist
    //     if (pair == address(0)) {
    //         pair = v3Factory.createPool(token0, token1, percentage);
    //     }
    //     // call v3 migrate
    //     v3Migrator.migrate(IV3Migrator.MigrateParams({
    //       pair: pair,
    //       liquidityToMigrate: ethAmountToUse,
    //       percentageToMigrate: 100,
    //       token0: token0,
    //       token1: token1,
    //       fee: percentage,
    //       tickLower: minToken1ToToken0Swap,
    //       tickUpper: maxToken1ToToken0Swap,
    //       amount0Min: 0,
    //       amount1Min: 0,
    //       recipient: msg.sender,
    //       deadline: 1,
    //       refundAsETH: false
    //     }));
    // }

    function civTradeList(
        address _owner
    ) external view returns (
        uint256 [] memory tokenIds
    ) {
        uint256 nftBalance = v3Nft.balanceOf(_owner);
        tokenIds = new uint256[](nftBalance);
        for (uint i = 0; i < nftBalance; i++) {
            tokenIds[i] = v3Nft.tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

}