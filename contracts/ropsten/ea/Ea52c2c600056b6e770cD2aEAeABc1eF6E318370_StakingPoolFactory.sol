// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "../Role/PoolCreator.sol";
import "./StakingPool.sol";
import "./RewardManager.sol";
import "../Distribution/USDRetriever.sol";

contract StakingPoolFactory is PoolCreator {
    TotemToken public immutable totemToken;
    RewardManager public immutable rewardManager;
    address public swapRouter;
    // TODO: we can add a mechanism to predict price of other top market coins 
    // like ETH, so it would be better not to use immutable addresses.
    // string  memory   CoinToPredictSymbol; change by Amir Motavas
    address immutable usdToken;
    address immutable btcToken;
    uint256 public stakingPoolTaxRate;
    uint256 public minimumStakeAmount;

    event PoolCreated(
        address indexed pool,
        address oracleContract,
        string CoinToPredictSymbol, 
        string poolType,
        // variables[0] = maturityTime,
        // variables[1] = lockTime,
        // variables[2] = sizeAllocation,
        // variables[3] = stakeApr,
        // variables[4] = prizeAmount,
        // variables[5] = usdPrizeAmount,
        // variables[6] = potentialCollabReward,
        // variables[7] = collaborativeRange,
        // variables[8] = stakingPoolTaxRate,
        // variables[9] = minimumStakeAmount,
        // the order of the variable is as above
        uint256[10] variables,
        bool isEnhancedEnabled
    );

    constructor(
        TotemToken _totemToken,
        RewardManager _rewardManager,
        address _swapRouter,
        address _usdToken,
        address _btcToken
    ) {
        totemToken = _totemToken;
        rewardManager = _rewardManager;
        swapRouter = _swapRouter;
        usdToken = _usdToken;
        btcToken = _btcToken;
        
        stakingPoolTaxRate = 300;

        // minimum amount of totem can be staked is 250 TOTM,
        // it's a mechanism to prevent DDOS attack
        minimumStakeAmount = 250*(10**18);
    }

    function create(
        address _oracleContract,
        // changed by Amir Motavas
        string memory _CoinToPredictSymbol,
        string memory _poolType,
        uint256 maturityTime,
        uint256 lockTime,
        uint256 sizeAllocation,
        uint256 stakeApr,
        uint256 prizeAmount,
        uint256 usdPrizeAmount,
        uint256 potentialCollabReward,
        uint256 collaborativeRange,
        bool isEnhancedEnabled
    ) external onlyPoolCreator returns (address) {

        uint256[10] memory variables =
            [
                maturityTime,
                lockTime,
                sizeAllocation,
                stakeApr,
                prizeAmount,
                usdPrizeAmount,
                potentialCollabReward,
                collaborativeRange,
                stakingPoolTaxRate,
                minimumStakeAmount
            ];
            
        address newPool = createPool( _oracleContract, _CoinToPredictSymbol, _poolType, variables, isEnhancedEnabled);

        return newPool;
    }

    function createPool(
        // changed by Amir Motavas
        address _oracleContract,
        string memory _CoinToPredictSymbol,
        string memory _poolType,
        uint256[10] memory _variables,
        bool isEnhancedEnabled
    ) internal returns (address) {

        address newPool =
            address(
                new StakingPool(
                    _poolType,
                    totemToken,
                    rewardManager,
                    // change by Amir Motavas
                    _msgSender(),
                    swapRouter,
                    _oracleContract,
                    usdToken,
                    btcToken,
                    _variables,
                    isEnhancedEnabled
                )
            );

        emit PoolCreated(
            newPool,
            // change by Amir Motavas
            _oracleContract,
            _CoinToPredictSymbol,
            _poolType,
            _variables,
            isEnhancedEnabled
        );

        rewardManager.addPool(newPool);

        return newPool;
    }


    
    function setSwapRouter(address _swapRouter) external onlyPoolCreator {
        require(_swapRouter != address(0), "0410");
        swapRouter = _swapRouter;
    }

    function setTaxRate(uint256 newStakingPoolTaxRate)
        external
        onlyPoolCreator
    {
        require(
            newStakingPoolTaxRate < 10000,
            "0420 Tax connot be over 100% (10000 BP)"
        );
        stakingPoolTaxRate = newStakingPoolTaxRate;
    }

    function setMinimuntToStake(uint256 newMinimumStakeAmount)
        external
        onlyPoolCreator
    {
        // TODO: any condition can be applied to check the minimum amount
        minimumStakeAmount = newMinimumStakeAmount;
    }
}