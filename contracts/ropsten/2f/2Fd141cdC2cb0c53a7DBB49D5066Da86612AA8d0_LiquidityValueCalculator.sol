pragma solidity ^0.6;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract LiquidityValueCalculator {
    address public factory;

    constructor(address factory_) public {
        factory = factory_;
    }

    function pairInfo(address tokenA, address tokenB)
        external
        view
        returns (
            uint256 reserveA,
            uint256 reserveB,
            uint256 totalSupply
        )
    {
        IUniswapV2Pair pair = IUniswapV2Pair(
            UniswapV2Library.pairFor(factory, tokenA, tokenB)
        );
        totalSupply = pair.totalSupply();
        (uint256 reserves0, uint256 reserves1, ) = pair.getReserves();
        (reserveA, reserveB) = tokenA == pair.token0()
            ? (reserves0, reserves1)
            : (reserves1, reserves0);
        return (reserveA, reserveB, totalSupply);
    }
}