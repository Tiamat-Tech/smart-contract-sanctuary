// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libs/SafeMath.sol";

contract LendFlareGaugeModel {
    using SafeMath for uint256;

    address[] public gauges;
    uint256 public n_gauges;

    mapping(address => uint256) gauge_weight;

    constructor(address _minter) public {}

    // 46650511811694184/1e18
    // 0.04665051181169418
    function add_gauge(address gauge, uint256 weight) public {
        n_gauges = n_gauges + 1;

        gauges.push(gauge);
        gauge_weight[gauge] = weight;
    }

    function gauge_relative_weight(address gauge)
        public
        view
        returns (uint256)
    {
        return gauge_weight[gauge];
    }
}