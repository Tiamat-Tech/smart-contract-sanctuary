//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BasePriceOracle} from "./BasePriceOracle.sol";
import {AggregatorV3Interface} from "../../interfaces/chainlink/AggregatorV3Interface.sol";
import "../../interfaces/uniswapV2/IUniswapV2ERC20.sol";
import "../../interfaces/uniswapV2/IUniswapV2Pair.sol";

/**
 * @title On-chain Price Oracle (Chainlink and Uniswap V2 (or equivalent))
 * @notice this computes the TVL (in USD) of FLURRY or rhoToken
 * for a specific intermediate currency.
 * WARNING - this reads the immediate price from the trading pair and is subject to flash loan attack
 * only use this as an indicative price, DO NOT use the price for any trading decisions
 * @dev this oracle is generic enough to handle different Uniswap pair order
 */
contract ChainlinkUniswapV2IndirectPrice is BasePriceOracle {
    uint8 public constant override decimals = 18;
    string public override description;

    // This price oracle assumes the price is computed in the order:
    // combined price = chainlink * base / intermediate
    //                = (intermediate / USD) * base / intermediate
    // Example:
    // (1) Chainlink: USDT / USD, (2) Uniswap: USDT / rhoUSDT
    //  => rhoUSDT / USD for USDT by (1)/(2)

    // Chainlink aggregator
    AggregatorV3Interface public aggregator; // intermediate / USD, for example "USDT / USD"
    uint8 private chainlinkDecimals;

    // Uniswap V2 token pair
    IUniswapV2Pair public uniswapV2Pair; // for example, "USDT / FLURRY"
    IUniswapV2ERC20 public baseToken;
    IUniswapV2ERC20 public intermediateToken;

    // oracle params
    bool public baseIsToken0;
    uint8 private baseDecimals;
    string public intermediateSymbol;
    address public intermediateAddr;
    uint8 private intermediateDecimals;

    function initialize(
        address aggregatorAddr,
        address uniswapV2PairAddr,
        address _baseAddr,
        address usdAddr
    ) public initializer {
        require(aggregatorAddr != address(0), "Chainlink aggregator address is 0");
        require(uniswapV2PairAddr != address(0), "Uniswap V2 pair address is 0");
        require(_baseAddr != address(0), "_baseAddr is 0");
        require(usdAddr != address(0), "usdAddr is 0");

        // Chainlink
        aggregator = AggregatorV3Interface(aggregatorAddr);
        chainlinkDecimals = aggregator.decimals();

        // Uniswap V2
        uniswapV2Pair = IUniswapV2Pair(uniswapV2PairAddr);
        address token0Addr = uniswapV2Pair.token0();
        address token1Addr = uniswapV2Pair.token1();
        require(token0Addr != address(0), "token0 address is 0");
        require(token1Addr != address(0), "token1 address is 0");

        // our setup
        require(_baseAddr == token0Addr || _baseAddr == token1Addr, "base address not in Uniswap V2 pair");
        // base currency
        baseAddr = _baseAddr;
        baseToken = IUniswapV2ERC20(baseAddr);
        baseSymbol = baseToken.symbol();
        baseDecimals = baseToken.decimals();
        // quote currency
        quoteSymbol = "USD";
        quoteAddr = usdAddr;
        // intermediate currency
        baseIsToken0 = baseAddr == token0Addr;
        intermediateAddr = baseIsToken0 ? token1Addr : token0Addr;
        intermediateToken = IUniswapV2ERC20(intermediateAddr);
        intermediateSymbol = intermediateToken.symbol();
        intermediateDecimals = intermediateToken.decimals();
        description = string(abi.encodePacked(baseSymbol, " / ", quoteSymbol));
    }

    function lastUpdate() external view override returns (uint256 updateAt) {
        (, , , uint256 chainlinkTime, ) = aggregator.latestRoundData();
        (, , uint32 blockTimestampLast) = uniswapV2Pair.getReserves();
        uint256 uniswapV2Time = uint256(blockTimestampLast);
        updateAt = chainlinkTime > uniswapV2Time ? chainlinkTime : uniswapV2Time; // use more recent `updateAt`
    }

    function priceInternal() internal view returns (uint256) {
        // Chainlink
        (, int256 answer, , , ) = aggregator.latestRoundData();
        if (answer <= 0) return type(uint256).max; // non-positive price feed is invalid
        // Uniswap V2
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        if (reserve0 == 0 || reserve1 == 0) return type(uint256).max; // zero reserve is invalid
        uint256 baseReserve = baseIsToken0 ? uint256(reserve0) : uint256(reserve1);
        uint256 intermediateReserve = baseIsToken0 ? uint256(reserve1) : uint256(reserve0);
        // combined price = chainlink * base / intermediate
        //                = (intermediate / USD) * base / intermediate
        return
            (10**(decimals + baseDecimals) * uint256(answer) * intermediateReserve) /
            (10**(chainlinkDecimals + intermediateDecimals) * baseReserve);
    }

    function price(address _baseAddr) external view override isValidSymbol(_baseAddr) returns (uint256) {
        uint256 priceFeed = priceInternal();
        if (priceFeed == type(uint256).max) return priceFeed;
        if (baseAddr == _baseAddr) return priceFeed;
        return 1e36 / priceFeed;
    }

    function priceByQuoteSymbol(address _quoteAddr) external view override isValidSymbol(_quoteAddr) returns (uint256) {
        uint256 priceFeed = priceInternal();
        if (priceFeed == type(uint256).max) return priceFeed;
        if (quoteAddr == _quoteAddr) return priceFeed;
        return 1e36 / priceFeed;
    }

    /**
     * @return true if both reserves are positive, false otherwise
     * NOTE: this is to avoid multiplication and division by 0
     */
    function isValidUniswapReserve() external view returns (bool) {
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        return reserve0 > 0 && reserve1 > 0;
    }
}