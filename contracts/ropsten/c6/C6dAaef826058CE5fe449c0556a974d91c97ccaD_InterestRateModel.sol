// SPDX-License-Identifier: MIT

import './interfaces/IInterestRateModel.sol';
import './storage/InterestRateModelStorage.sol';

import './libraries/Math.sol';

pragma solidity ^0.8.4;

/// @title InterestRateModel
/// @notice Interest rates model in ELYFI. ELYFI's interest rates are determined by algorithms.
/// When borrowing demand increases, borrowing interest and pool ROI increase,
/// suppressing excessove borrowing demand and inducing depositors to supply liquidity.
/// Therefore, ELYFI's interest rates are influenced by the Pool `utilizationRatio`.
/// The Pool utilization ratio is a variable representing the current borrowing
/// and deposit status of the Pool. The interest rates of ELYFI exhibits some form of kink.
/// They sharply change at some defined threshold, `optimalUtilazationRate`.
contract InterestRateModel is IInterestRateModel, InterestRateModelStorage {
  using Math for uint256;

  constructor(IProtocolAddressProvider protocolAddressProvider) {
    _protocolAddressProvider = protocolAddressProvider;
  }

  struct calculateRatesLocalVars {
    uint256 totalDebt;
    uint256 utilizationRate;
    uint256 newBorrowAPY;
    uint256 newDepositAPY;
  }

  modifier onlyGovernance() {
    require(
      msg.sender == IProtocolAddressProvider(_protocolAddressProvider).getGovernance(),
      'Only Governance Allowed'
    );
    _;
  }

  /// @inheritdoc IInterestRateModel
  function calculateRates(
    address asset,
    uint256 poolRemainingLiquidityAfterAction,
    uint256 totalDebtTokenSupply,
    uint256 poolFactor
  ) external view override returns (uint256 newBorrowAPY, uint256 newDepositAPY) {
    InterestRateModelParam memory param = _interestRateModel[asset];

    calculateRatesLocalVars memory vars;

    vars.totalDebt = totalDebtTokenSupply;
    vars.utilizationRate = _getUtilizationRate(vars.totalDebt, poolRemainingLiquidityAfterAction);
    vars.newBorrowAPY = 0;

    if (vars.utilizationRate <= param.optimalUtilizationRate) {
      vars.newBorrowAPY =
        param.borrowRateBase +
        (
          (param.borrowRateOptimal - param.borrowRateBase)
            .rayDiv(param.optimalUtilizationRate)
            .rayMul(vars.utilizationRate)
        );
    } else {
      vars.newBorrowAPY =
        param.borrowRateOptimal +
        (
          (param.borrowRateMax - param.borrowRateOptimal)
            .rayDiv(Math.ray() - param.optimalUtilizationRate)
            .rayMul(vars.utilizationRate - param.optimalUtilizationRate)
        );
    }

    vars.newDepositAPY = vars.newBorrowAPY.rayMul(vars.utilizationRate).rayMul(
      Math.RAY - poolFactor
    );

    return (vars.newBorrowAPY, vars.newDepositAPY);
  }

  /// @inheritdoc IInterestRateModel
  /// @custom:check -  Make sure that `msg.sender` is core contract
  /// @custom:check - InterestRateModelParams with `asset` does not already exist
  /// @custom:effect - set `_interestRateModel[asset]` to given params
  /// @custom:interaction - emit `AddNewPoolInterestRateModel` event
  function addNewPoolInterestRateModel(
    address asset,
    uint256 optimalUtilizationRate,
    uint256 borrowRateBase,
    uint256 borrowRateOptimal,
    uint256 borrowRateMax
  ) external override onlyGovernance {
    require(_interestRateModel[asset].borrowRateMax == 0, 'Model already exists');

    _interestRateModel[asset].optimalUtilizationRate = optimalUtilizationRate;
    _interestRateModel[asset].borrowRateBase = borrowRateBase;
    _interestRateModel[asset].borrowRateOptimal = borrowRateOptimal;
    _interestRateModel[asset].borrowRateMax = borrowRateMax;

    emit AddNewPoolInterestRateModel(
      asset,
      optimalUtilizationRate,
      borrowRateBase,
      borrowRateOptimal,
      borrowRateMax
    );
  }

  /// @inheritdoc IInterestRateModel
  /// @custom:check - Make sure that `msg.sender` is core contract
  /// @custom:effect - update `_interestRateModel[asset].optimalUtilizationRate` to `optimalUtilizationRate`
  /// @custom:interaction - emit `UpdateOptimalUtilizationRate` event
  function updateOptimalUtilizationRate(address asset, uint256 optimalUtilizationRate)
    external
    override
    onlyGovernance
  {
    _interestRateModel[asset].optimalUtilizationRate = optimalUtilizationRate;
    emit UpdateOptimalUtilizationRate(optimalUtilizationRate);
  }

  /// @inheritdoc IInterestRateModel
  /// @custom:check - Make sure that `msg.sender` is core contract
  /// @custom:effect - update `_interestRateModel[asset].borrowRateBase` to `borrowRateBase`
  /// @custom:interaction - emit `UpdateBorrowRateBase` event
  function updateBorrowRateBase(address asset, uint256 borrowRateBase)
    external
    override
    onlyGovernance
  {
    _interestRateModel[asset].borrowRateBase = borrowRateBase;
    emit UpdateBorrowRateBase(borrowRateBase);
  }

  /// @inheritdoc IInterestRateModel
  /// @custom:check - Make sure that `msg.sender` is core contract
  /// @custom:effect - update `_interestRateModel[asset].borrowRateOptimal` to `borrowRateOptimal`
  /// @custom:interaction - emit `UpdateBorrowRateOptimal` event
  function updateBorrowRateOptimal(address asset, uint256 borrowRateOptimal)
    external
    override
    onlyGovernance
  {
    _interestRateModel[asset].borrowRateOptimal = borrowRateOptimal;
    emit UpdateBorrowRateOptimal(borrowRateOptimal);
  }

  /// @inheritdoc IInterestRateModel
  /// @custom:check - Make sure that `msg.sender` is core contract
  /// @custom:effect - update `_interestRateModel[asset].borrowRateMax` to `borrowRateMax`
  /// @custom:interaction - emit `UpdateBorrowRateMax` event
  function updateBorrowRateMax(address asset, uint256 borrowRateMax)
    external
    override
    onlyGovernance
  {
    _interestRateModel[asset].borrowRateMax = borrowRateMax;
    emit UpdateBorrowRateMax(borrowRateMax);
  }

  /// @inheritdoc IInterestRateModel
  function getInterestRateModelParam(address asset)
    external
    view
    override
    returns (
      uint256 optimalUtilizationRate,
      uint256 borrowRateBase,
      uint256 borrowRateOptimal,
      uint256 borrowRateMax
    )
  {
    optimalUtilizationRate = _interestRateModel[asset].optimalUtilizationRate;
    borrowRateBase = _interestRateModel[asset].borrowRateBase;
    borrowRateOptimal = _interestRateModel[asset].borrowRateOptimal;
    borrowRateMax = _interestRateModel[asset].borrowRateMax;
  }

  function getUtilizationRate(uint256 totalDebt, uint256 availableLiquidity)
    external
    pure
    override
    returns (uint256 utilizationRate)
  {
    utilizationRate = _getUtilizationRate(totalDebt, availableLiquidity);
  }

  /// @inheritdoc IInterestRateModel
  function getProtocolAddressProvider()
    external
    override
    returns (IProtocolAddressProvider protocolAddressProvider)
  {}

  function _getUtilizationRate(uint256 totalDebt, uint256 availableLiquidity)
    private
    pure
    returns (uint256)
  {
    return totalDebt == 0 ? 0 : totalDebt.rayDiv(availableLiquidity + totalDebt);
  }
}