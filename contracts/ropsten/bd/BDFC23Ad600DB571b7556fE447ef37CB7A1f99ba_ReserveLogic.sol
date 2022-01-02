// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../lendingpool/DataTypes.sol";
import "../interfaces/IVariableDebtToken.sol";
import "../interfaces/IReserveInterestRateStrategy.sol";
import "./MathUtils.sol";
import "./KyokoMath.sol";
import "./PercentageMath.sol";
import "../interfaces/IKToken.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";


library ReserveLogic {
    using SafeMathUpgradeable for uint256;
	using KyokoMath for uint256;
    using PercentageMath for uint256;

    event ReserveDataUpdated(
        address indexed asset,
        uint256 liquidityRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );

    uint256 constant MAX_VALID_RESERVE_FACTOR = 65535;

    using ReserveLogic for DataTypes.ReserveData;

    // Initializes a reserve
    function init(
        DataTypes.ReserveData storage reserve, 
        address kTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress
    ) external {
        require(reserve.kTokenAddress == address(0), "the reserve already initialized");

        reserve.isActive = true;
        reserve.liquidityIndex = uint128(KyokoMath.ray());
        reserve.variableBorrowIndex = uint128(KyokoMath.ray());
        reserve.kTokenAddress = kTokenAddress;
        reserve.variableDebtTokenAddress = variableDebtTokenAddress;
        reserve.interestRateStrategyAddress = interestRateStrategyAddress;
    }

    // 
    function updateState(DataTypes.ReserveData storage reserve) internal {
        // 获取浮动债务的 scaled 数量, 即缩放到 t_0 时刻的总数量
        uint256 scaledVariableDebt =
            IVariableDebtToken(reserve.variableDebtTokenAddress).scaledTotalSupply();
        // 缓存更新之前的值
        uint256 previousVariableBorrowIndex = reserve.variableBorrowIndex;
        uint256 previousLiquidityIndex = reserve.liquidityIndex;
        uint40 lastUpdatedTimestamp = reserve.lastUpdateTimestamp;

        // 更新 index 变量
        (uint256 newLiquidityIndex, uint256 newVariableBorrowIndex) =
            _updateIndexes(
                reserve,
                scaledVariableDebt,
                previousLiquidityIndex,
                previousVariableBorrowIndex,
                lastUpdatedTimestamp
            );

        // 若有新增资产将其中一部分存入金库
        _mintToTreasury(
            reserve,
            scaledVariableDebt,
            previousVariableBorrowIndex,
            newLiquidityIndex,
            newVariableBorrowIndex
            // lastUpdatedTimestamp
        );
    }

    function _updateIndexes(
        DataTypes.ReserveData storage reserve,
        uint256 scaledVariableDebt,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex,
        uint40 timestamp
    ) internal returns (uint256, uint256) {
        // 缓存之前的流动性收益率
        uint256 currentLiquidityRate = reserve.currentLiquidityRate;

        // 缓存之前的每单位流动性累计本息总额
        uint256 newLiquidityIndex = liquidityIndex;
        // 缓存每单位浮动利率类型债务的累计本息总额
        uint256 newVariableBorrowIndex = variableBorrowIndex;

        //only cumulating if there is any income being produced
        // 只有当有收益率时, 执行累计逻辑
        if (currentLiquidityRate > 0) {
            // 累计收益率 通过计算将年化收益率切分成每秒，然后线性累加这段时间的收益率
            // 1 + ratePerSecond * (delta_t / seconds in a year)
            uint256 cumulatedLiquidityInterest =
                MathUtils.calculateLinearInterest(currentLiquidityRate, timestamp);
            // 更新每单位流动性的本息总额
            newLiquidityIndex = cumulatedLiquidityInterest.rayMul(liquidityIndex);
            require(newLiquidityIndex <= type(uint128).max, "RL_LIQUIDITY_INDEX_OVERFLOW");

            reserve.liquidityIndex = uint128(newLiquidityIndex);

            //as the liquidity rate might come only from stable rate loans, we need to ensure
            //that there is actual variable debt before accumulating    
            // 浮动类型债务, 更新浮动债务的每单位累计本息总额
            if (scaledVariableDebt != 0) {
                // 将年化利率切分成每秒, 然后以时间差为指数计算复利后的每单位累计本息总额
                // (1 + ratePerSecond) ^ delta_t
                uint256 cumulatedVariableBorrowInterest =
                    MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, timestamp);
                // 更新浮动债务的每单位累计本息总额
                newVariableBorrowIndex = cumulatedVariableBorrowInterest.rayMul(variableBorrowIndex);
                require(
                    newVariableBorrowIndex <= type(uint128).max,
                    "RL_VARIABLE_BORROW_INDEX_OVERFLOW"
                );
                // calculateCompoundedInterest 返回的uint256类型, 转换成uint128
                reserve.variableBorrowIndex = uint128(newVariableBorrowIndex);
            }
        }

        //solium-disable-next-line
        // 记录更新的时间戳
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
        return (newLiquidityIndex, newVariableBorrowIndex);
    }

    struct MintToTreasuryLocalVars {
        // uint256 currentStableDebt;
        // uint256 principalStableDebt;
        // uint256 previousStableDebt;
        uint256 currentVariableDebt;
        uint256 previousVariableDebt;
        // uint256 avgStableRate;
        // uint256 cumulatedStableInterest;
        uint256 totalDebtAccrued;
        uint256 amountToMint;
        uint16 reserveFactor;
        uint40 stableSupplyUpdatedTimestamp;
    }

    function _mintToTreasury(
        DataTypes.ReserveData storage reserve,
        uint256 scaledVariableDebt,
        uint256 previousVariableBorrowIndex,
        uint256 newLiquidityIndex,
        uint256 newVariableBorrowIndex
        // uint40 timestamp
    ) internal {
        MintToTreasuryLocalVars memory vars;

        vars.reserveFactor = getReserveFactor(reserve);

        if (vars.reserveFactor == 0) {
            return;
        }

        //fetching the principal, total stable debt and the avg stable rate
        // (
        //     vars.principalStableDebt,
        //     vars.currentStableDebt,
        //     vars.avgStableRate,
        //     vars.stableSupplyUpdatedTimestamp
        // ) = IStableDebtToken(reserve.stableDebtTokenAddress).getSupplyData();

        //calculate the last principal variable debt
        // 计算最近的可变债务
        vars.previousVariableDebt = scaledVariableDebt.rayMul(previousVariableBorrowIndex);

        //calculate the new total supply after accumulation of the index
        // 计算浮动债务的累积本息总额
        vars.currentVariableDebt = scaledVariableDebt.rayMul(newVariableBorrowIndex);

        //calculate the stable debt until the last timestamp update
        // vars.cumulatedStableInterest = MathUtils.calculateCompoundedInterest(
        //     vars.avgStableRate,
        //     vars.stableSupplyUpdatedTimestamp,
        //     timestamp
        // );

        // vars.previousStableDebt = vars.principalStableDebt.rayMul(vars.cumulatedStableInterest);

        //debt accrued is the sum of the current debt minus the sum of the debt at the last update
        vars.totalDebtAccrued = vars
            .currentVariableDebt
            // .add(vars.currentStableDebt)
            .sub(vars.previousVariableDebt);
            // .sub(vars.previousStableDebt);

        vars.amountToMint = vars.totalDebtAccrued.percentMul(vars.reserveFactor);

        if (vars.amountToMint != 0) {
            IKToken(reserve.kTokenAddress).mintToTreasury(vars.amountToMint, newLiquidityIndex);
        }
    }

    struct UpdateInterestRatesLocalVars {
        address stableDebtTokenAddress;
        uint256 availableLiquidity;
        uint256 newLiquidityRate;
        uint256 newVariableRate;
        uint256 totalVariableDebt;
    }

    /**
    * @dev Updates the reserve current stable borrow rate, the current variable borrow rate and the current liquidity rate
    * @param reserve The address of the reserve to be updated
    * @param liquidityAdded The amount of liquidity added to the protocol (deposit or repay) in the previous action
    * @param liquidityTaken The amount of liquidity taken from the protocol (redeem or borrow)
    **/
    function updateInterestRates(
        DataTypes.ReserveData storage reserve,
        address reserveAddress,
        address kTokenAddress,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        UpdateInterestRatesLocalVars memory vars;



        //calculates the total variable debt locally using the scaled total supply instead
        //of totalSupply(), as it's noticeably cheaper. Also, the index has been
        //updated by the previous updateState() call
        vars.totalVariableDebt = IVariableDebtToken(reserve.variableDebtTokenAddress)
            .scaledTotalSupply()
            .rayMul(reserve.variableBorrowIndex);

        (
            vars.newLiquidityRate,
            vars.newVariableRate
        ) = IReserveInterestRateStrategy(reserve.interestRateStrategyAddress).calculateInterestRates(
            reserveAddress,
            kTokenAddress,
            liquidityAdded,
            liquidityTaken,
            vars.totalVariableDebt,
            getReserveFactor(reserve)
        );

        require(vars.newLiquidityRate <= type(uint128).max, "RL_LIQUIDITY_RATE_OVERFLOW");
        require(vars.newVariableRate <= type(uint128).max, "RL_VARIABLE_BORROW_RATE_OVERFLOW");

        reserve.currentLiquidityRate = uint128(vars.newLiquidityRate);
        reserve.currentVariableBorrowRate = uint128(vars.newVariableRate);

        emit ReserveDataUpdated(
            reserveAddress,
            vars.newLiquidityRate,
            vars.newVariableRate,
            reserve.liquidityIndex,
            reserve.variableBorrowIndex
        );
    }

    function getNormalizedDebt(DataTypes.ReserveData storage reserve)
        internal
        view
        returns (uint256)
    {
        uint40 timestamp = reserve.lastUpdateTimestamp;

        //solium-disable-next-line
        if (timestamp == uint40(block.timestamp)) {
            //if the index was updated in the same block, no need to perform any calculation
            return reserve.variableBorrowIndex;
        }

        uint256 cumulated =
            MathUtils.calculateCompoundedInterest(reserve.currentVariableBorrowRate, timestamp).rayMul(
                reserve.variableBorrowIndex
            );

        return cumulated;
    }

    function getNormalizedIncome(DataTypes.ReserveData storage reserve)
        internal
        view
        returns (uint256)
    {
        uint40 timestamp = reserve.lastUpdateTimestamp;

        //solium-disable-next-line
        if (timestamp == uint40(block.timestamp)) {
        //if the index was updated in the same block, no need to perform any calculation
        return reserve.liquidityIndex;
        }

        uint256 cumulated =
            MathUtils.calculateLinearInterest(reserve.currentLiquidityRate, timestamp).rayMul(
                reserve.liquidityIndex
            );

        return cumulated;
    }

    function setActive(DataTypes.ReserveData storage self, bool active) internal {
        self.isActive = active;
    }

    function getActive(DataTypes.ReserveData storage self) internal view returns (bool) {
        return self.isActive;
    }
    
    function setReserveFactor(DataTypes.ReserveData storage self, uint16 reserveFactor)
        internal 
    {
        require(reserveFactor <= MAX_VALID_RESERVE_FACTOR, "RC_INVALID_RESERVE_FACTOR");
        self.factor = reserveFactor;
    }

    function getReserveFactor(DataTypes.ReserveData storage self)
        internal
        view
        returns (uint16)
    {
        return self.factor;
    }

    function getDecimal(DataTypes.ReserveData storage self)
        internal
        view
        returns (uint8)
    {
        return self.decimals;
    }
}