// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IPollTogether.sol";
import "@pooltogether/pooltogether-contracts/contracts/builders/PoolWithMultipleWinnersBuilder.sol";

contract PoolTConnector is IPoolTogetherData{
    address public strategy_address;

    constructor(address _strategy_address)public{
        strategy_address = _strategy_address;
    }

    function initializePool(CompoundPrizePoolConfig memory poolConfig, MultipleWinnersBuilder.MultipleWinnersConfig memory prizeStrategy, uint8 decimals) public{
        IPoolTogether poolInstance = IPoolTogether(strategy_address);
        poolInstance.createCompoundMultipleWinners(poolConfig,prizeStrategy, decimals);
    }
}