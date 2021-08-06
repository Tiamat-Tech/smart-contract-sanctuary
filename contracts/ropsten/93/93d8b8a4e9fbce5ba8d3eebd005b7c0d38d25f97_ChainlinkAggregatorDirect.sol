//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {BasePriceOracle} from "./BasePriceOracle.sol";
import {AggregatorV3Interface} from "../../interfaces/chainlink/AggregatorV3Interface.sol";

/**
 * @notice On-chain Price Oracle
 * reads the price feed from 1 Chainlink aggregator directly
 * `decimals` and `description` are copied as-is
 */
contract ChainlinkAggregatorDirect is BasePriceOracle {
    uint8 public override decimals;
    string public override description;

    AggregatorV3Interface public aggregator;

    function initialize(
        address aggregatorAddr,
        string memory _baseSymbol,
        string memory _quoteSymbol,
        address _baseAddr,
        address _quoteAddr
    ) public initializer {
        BasePriceOracle.__initialize();
        require(aggregatorAddr != address(0), "Chainlink aggregator address is 0");
        aggregator = AggregatorV3Interface(aggregatorAddr);
        decimals = aggregator.decimals();
        description = aggregator.description();
        super.setSymbols(_baseSymbol, _quoteSymbol, _baseAddr, _quoteAddr);
    }

    function lastUpdate() external view override returns (uint256 updateAt) {
        (, , , updateAt, ) = aggregator.latestRoundData();
    }

    /**
     * @dev internal function to find "baseSymbol / quoteSymbol" rate
     * @return rate in `decimals`, or type(uint256).max if the rate is invalid
     */
    function priceInternal() internal view returns (uint256) {
        (, int256 answer, , , ) = aggregator.latestRoundData();
        if (answer <= 0) return type(uint256).max; // non-positive price feed is invalid
        return uint256(answer);
    }

    function price(address _baseAddr) external view override isValidSymbol(_baseAddr) returns (uint256) {
        if (baseAddr == _baseAddr) return priceInternal();
        return 10**(decimals * 2) / priceInternal();
    }

    function priceByQuoteSymbol(address _quoteAddr) external view override isValidSymbol(_quoteAddr) returns (uint256) {
        if (quoteAddr == _quoteAddr) return priceInternal();
        return 10**(decimals * 2) / priceInternal();
    }
}