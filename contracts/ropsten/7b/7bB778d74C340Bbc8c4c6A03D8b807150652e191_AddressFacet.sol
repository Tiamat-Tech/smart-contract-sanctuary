// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {BFacetOwner} from "./base/BFacetOwner.sol";
import {LibAddress} from "../libraries/LibAddress.sol";

contract AddressFacet is BFacetOwner {
    using LibAddress for address;

    event LogSetOracleAggregator(address indexed oracleAggregator);

    event LogSetGasPriceOracle(address indexed gasPriceOracle);

    function setOracleAggregator(address _oracleAggregator) external onlyOwner {
        _oracleAggregator.setOracleAggregator();
        emit LogSetOracleAggregator(_oracleAggregator);
    }

    function setGasPriceOracle(address _gasPriceOracle) external onlyOwner {
        _gasPriceOracle.setGasPriceOracle();
        emit LogSetGasPriceOracle(_gasPriceOracle);
    }

    function getOracleAggregator() public view returns (address) {
        return LibAddress.getOracleAggregator();
    }

    function getGasPriceOracle() public view returns (address) {
        return LibAddress.getGasPriceOracle();
    }
}