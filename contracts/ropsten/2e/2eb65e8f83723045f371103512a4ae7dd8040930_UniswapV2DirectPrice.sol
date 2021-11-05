//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {BasePriceOracle} from "./BasePriceOracle.sol";
import "../../interfaces/uniswapV2/IUniswapV2Pair.sol";

/**
 * @title On-chain Price Oracle for IUniswapV2Pair
 * @notice WARNING - this reads the immediate price from the trading pair and is subject to flash loan attack
 * only use this as an indicative price, DO NOT use the price for any trading decisions
 */
contract UniswapV2DirectPrice is BasePriceOracle {
    uint8 public constant override decimals = 18;
    string public override description;

    // Uniswap V2 token pair
    IUniswapV2Pair public uniswapV2Pair;
    IERC20MetadataUpgradeable public token0; // pair token with the lower sort order
    IERC20MetadataUpgradeable public token1; // pair token with the higher sort order

    // Uniswap token decimals
    uint8 private decimals0;
    uint8 private decimals1;

    function initialize(address uniswapV2PairAddr) public initializer {
        require(uniswapV2PairAddr != address(0), "Uniswap V2 pair address is 0");
        uniswapV2Pair = IUniswapV2Pair(uniswapV2PairAddr);
        address _baseAddr = uniswapV2Pair.token0();
        address _quoteAddr = uniswapV2Pair.token1();

        require(_baseAddr != address(0), "token0 address is 0");
        require(_quoteAddr != address(0), "token1 address is 0");
        token0 = IERC20MetadataUpgradeable(_baseAddr);
        token1 = IERC20MetadataUpgradeable(_quoteAddr);
        decimals0 = token0.decimals();
        decimals1 = token1.decimals();

        super.setSymbols(token0.symbol(), token1.symbol(), _baseAddr, _quoteAddr);
        description = string(abi.encodePacked(baseSymbol, " / ", quoteSymbol));
    }

    /**
     * @dev blockTimestampLast is the `block.timestamp` (mod 2**32) of the last block
     * during which an interaction occured for the pair.
     * NOTE: 2**32 is about 136 years. It is safe to cast the timestamp to uint256.
     */
    function lastUpdate() external view override returns (uint256 updateAt) {
        (, , uint32 blockTimestampLast) = uniswapV2Pair.getReserves();
        updateAt = uint256(blockTimestampLast);
    }

    function priceInternal() internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        // avoid mul and div by 0
        if (reserve0 > 0 && reserve1 > 0) {
            return (10**(decimals + decimals1 - decimals0) * uint256(reserve0)) / uint256(reserve1);
        }
        return type(uint256).max;
    }

    function price(address _baseAddr) external view override isValidSymbol(_baseAddr) returns (uint256) {
        uint256 priceFeed = priceInternal();
        if (priceFeed == type(uint256).max) return priceFeed;
        if (quoteAddr == _baseAddr) return priceFeed;
        return 1e36 / priceFeed;
    }

    function priceByQuoteSymbol(address _quoteAddr) external view override isValidSymbol(_quoteAddr) returns (uint256) {
        uint256 priceFeed = priceInternal();
        if (priceFeed == type(uint256).max) return priceFeed;
        if (baseAddr == _quoteAddr) return priceFeed;
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