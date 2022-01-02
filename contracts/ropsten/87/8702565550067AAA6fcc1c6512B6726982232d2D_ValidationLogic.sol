// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../lendingpool/DataTypes.sol";
import "../credit/CreditSystem.sol";
import "./KyokoMath.sol";
import "./PercentageMath.sol";
import "./ReserveLogic.sol";
import "./GenericLogic.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * @dev this library as a data validitaion
 */
library ValidationLogic {
    using ReserveLogic for DataTypes.ReserveData;
    using SafeMathUpgradeable for uint256;
    using KyokoMath for uint256;
    using PercentageMath for uint256;

    uint256 public constant REBALANCE_UP_LIQUIDITY_RATE_THRESHOLD = 4000;
    uint256 public constant REBALANCE_UP_USAGE_RATIO_THRESHOLD = 0.95 * 1e27; //usage ratio of 95%

    /**
    * @dev Validates a deposit action
    * @param reserve The reserve object on which the user is depositing
    * @param amount The amount to be deposited
    */
    function validateDeposit(DataTypes.ReserveData storage reserve, uint256 amount) external view {
        bool isActive = reserve.getActive();
        require(amount != 0, "VL_INVALID_AMOUNT");
        require(isActive, "VL_NO_ACTIVE_RESERVE");
    }

    /**
    * @dev Validates a withdraw action
    * @param reserveAddress The address of the reserve
    * @param amount The amount to be withdrawn
    * @param userBalance The balance of the user
    * @param reservesData The reserves state
    * @param reserves The addresses of the reserves
    * @param reservesCount The number of reserves
    */
    function validateWithdraw(
        address reserveAddress,
        uint256 amount,
        uint256 userBalance,
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reserves,
        uint256 reservesCount
    ) external view {
        require(amount != 0, "VL_INVALID_AMOUNT");
        require(amount <= userBalance, "VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE");

        bool isActive = reservesData[reserveAddress].getActive();
        require(isActive, "VL_NO_ACTIVE_RESERVE");

        // require(
        //     GenericLogic.balanceDecreaseAllowed(
        //         // reserveAddress,
        //         msg.sender,
        //         // amount,
        //         reservesData,
        //         reserves,
        //         reservesCount
        //     ),
        //     "VL_TRANSFER_NOT_ALLOWED"
        // );
    }

    struct ValidateBorrowLocalVars {
        uint256 userBorrowBalance;
        uint256 availableLiquidity;
        bool isActive;
    }

    /**
    * @dev Validates a borrow action
    * @param availableBorrowsInUSD available borrows in USD
    * @param reserve The reserve state from which the user is borrowing
    * @param amount The amount to be borrowed
    */

    function validateBorrow(
        uint256 availableBorrowsInUSD,
        DataTypes.ReserveData storage reserve,
        uint256 amount
    ) external view {
        ValidateBorrowLocalVars memory vars;
        require(availableBorrowsInUSD > 0, "available credit line not enough");
        uint256 borrowsAmountInUSD = amount.div(10**reserve.decimals);
        require(borrowsAmountInUSD <= availableBorrowsInUSD, "borrows exceed credit line");
        
        vars.isActive = reserve.getActive();

        require(vars.isActive, "VL_NO_ACTIVE_RESERVE");
        require(amount > 0, "VL_INVALID_AMOUNT");

        // vars.userBorrowBalance = GenericLogic.calculateUserAccountData(
        //     userAddress,
        //     reservesData,
        //     reserves,
        //     reservesCount
        // );
        // vars.availableLiquidity = IERC20(reserve.kTokenAddress).totalSupply().sub(vars.userBorrowBalance);
        // require(amount < vars.availableLiquidity, "AMOUNT_EXCEED_AVAILABLELIQUIDITY");
        // require(amount < reserve.);
    }

    /**
    * @dev Validates a repay action
    * @param reserve The reserve state from which the user is repaying
    * @param amountSent The amount sent for the repayment. Can be an actual value or uint(-1)
    * @param onBehalfOf The address of the user msg.sender is repaying for
    * @param variableDebt The borrow balance of the user
    */
    function validateRepay(
        DataTypes.ReserveData storage reserve,
        uint256 amountSent,
        address onBehalfOf,
        uint256 variableDebt
    ) external view {
        bool isActive = reserve.getActive();

        require(isActive, "VL_NO_ACTIVE_RESERVE");

        require(amountSent > 0, "VL_INVALID_AMOUNT");

        require(variableDebt > 0, "VL_NO_DEBT_OF_SELECTED_TYPE");

        require(
            amountSent != type(uint256).min || msg.sender == onBehalfOf,
            "VL_NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF"
        );
    }
}