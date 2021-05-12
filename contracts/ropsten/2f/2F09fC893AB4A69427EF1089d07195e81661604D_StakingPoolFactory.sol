// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "../Role/PoolCreator.sol";
import "./StakingPool.sol";
import "./RewardManager.sol";
import "../Distribution/BTCDistributor.sol";
import "../Distribution/USDRetriever.sol";

contract StakingPoolFactory is PoolCreator {
    TotemToken public totemToken;
    RewardManager public rewardManager;
    BTCDistributor btcDistributor;
    address public oracleContract;
    //TODO: Make stakingPoolTaxRate uint16 as its value will never cross 10000
    uint256 public stakingPoolTaxRate = 300;
    address usdToken;
    address btcToken;

    event PoolCreated(
        address indexed pool,
        uint256 maturityTime,
        uint256 launchTime,
        uint256 sizeAllocation,
        uint256 stakeApr,
        uint256 prizeAmount,
        uint256 usdPrizeAmount
    );

    constructor(
        TotemToken _totemToken,
        RewardManager _rewardManager,
        BTCDistributor _btcDistributor,
        address _usdToken,
        address _btcToken
    ) {
        totemToken = _totemToken;
        rewardManager = _rewardManager;
        btcDistributor = _btcDistributor;
        usdToken = _usdToken;
        btcToken = _btcToken;
    }

    function create(
        uint256 maturityTime,
        uint256 launchTime,
        uint256 sizeAllocation,
        uint256 stakeApr,
        uint256 prizeAmount,
        uint256 usdPrizeAmount
    ) public onlyPoolCreator returns (address) {
        address newPool =
            address(
                new StakingPool(
                    totemToken,
                    this,
                    rewardManager,
                    btcDistributor,
                    oracleContract,
                    usdToken,
                    btcToken,
                    maturityTime,
                    launchTime,
                    sizeAllocation,
                    stakeApr,
                    prizeAmount,
                    usdPrizeAmount,
                    stakingPoolTaxRate
                )
            );

        emit PoolCreated(
            newPool,
            maturityTime,
            launchTime,
            sizeAllocation,
            stakeApr,
            prizeAmount,
            usdPrizeAmount
        );

        rewardManager.addPool(newPool);

        return newPool;
    }

    function setOracleContract(address _oracleContract) public onlyPoolCreator {
        require(_oracleContract != address(0));
        oracleContract = _oracleContract;
    }

    function setTaxRate(uint256 newStakingPoolTaxRate) public onlyPoolCreator {
        require(
            newStakingPoolTaxRate < 10000,
            "Tax connot be over 100% (10000 BP)"
        );
        stakingPoolTaxRate = newStakingPoolTaxRate;
    }
}