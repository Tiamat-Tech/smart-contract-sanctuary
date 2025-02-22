// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import '../../tools/upgradeability/VersionedInitializable.sol';
import '../../tools/upgradeability/IProxy.sol';
import '../../tools/upgradeability/ProxyAdminBase.sol';
import '../../access/interfaces/IMarketAccessController.sol';
import '../../access/MarketAccessBitmask.sol';
import '../../interfaces/ILendingPoolConfigurator.sol';
import '../../interfaces/IManagedLendingPool.sol';
import '../../interfaces/ILendingPoolForTokens.sol';
import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../tools/Errors.sol';
import '../../tools/math/PercentageMath.sol';
import '../libraries/configuration/ReserveConfiguration.sol';
import '../libraries/types/DataTypes.sol';
import '../tokenization/interfaces/IInitializablePoolToken.sol';
import '../tokenization/interfaces/PoolTokenConfig.sol';

/// @dev Implements configuration methods for the LendingPool
contract LendingPoolConfigurator is
  ProxyAdminBase,
  VersionedInitializable,
  MarketAccessBitmask(IMarketAccessController(address(0))),
  ILendingPoolConfigurator
{
  using PercentageMath for uint256;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  ICombinedPool internal pool;

  uint256 private constant CONFIGURATOR_REVISION = 0x1;

  function getRevision() internal pure virtual override returns (uint256) {
    return CONFIGURATOR_REVISION;
  }

  function initialize(IMarketAccessController provider)
    public
    initializerRunAlways(CONFIGURATOR_REVISION)
  {
    _remoteAcl = provider;
    pool = ICombinedPool(provider.getLendingPool());
  }

  /// @dev Initializes reserves in batch
  function batchInitReserve(InitReserveInput[] calldata input) external onlyPoolAdmin {
    for (uint256 i = 0; i < input.length; i++) {
      _initReserve(input[i]);
    }
  }

  function _initReserve(InitReserveInput calldata input) internal {
    PoolTokenConfig memory config =
      PoolTokenConfig({
        pool: address(pool),
        treasury: input.treasury,
        underlyingAsset: input.underlyingAsset
      });

    address depositTokenProxyAddress =
      _initTokenWithProxy(
        input.depositTokenImpl,
        abi.encodeWithSelector(
          IInitializablePoolToken.initialize.selector,
          config,
          input.depositTokenName,
          input.depositTokenSymbol,
          input.underlyingAssetDecimals,
          input.params
        )
      );

    address stableDebtTokenProxyAddress =
      _initTokenWithProxy(
        input.stableDebtTokenImpl,
        abi.encodeWithSelector(
          IInitializablePoolToken.initialize.selector,
          config,
          input.stableDebtTokenName,
          input.stableDebtTokenSymbol,
          input.underlyingAssetDecimals,
          input.params
        )
      );

    address variableDebtTokenProxyAddress =
      _initTokenWithProxy(
        input.variableDebtTokenImpl,
        abi.encodeWithSelector(
          IInitializablePoolToken.initialize.selector,
          config,
          input.variableDebtTokenName,
          input.variableDebtTokenSymbol,
          input.underlyingAssetDecimals,
          input.params
        )
      );

    pool.initReserve(
      DataTypes.InitReserveData(
        input.underlyingAsset,
        depositTokenProxyAddress,
        stableDebtTokenProxyAddress,
        variableDebtTokenProxyAddress,
        input.strategy,
        input.externalStrategy
      )
    );

    DataTypes.ReserveConfigurationMap memory currentConfig =
      pool.getConfiguration(input.underlyingAsset);

    currentConfig.setDecimals(input.underlyingAssetDecimals);

    currentConfig.setActive(true);
    currentConfig.setFrozen(false);

    pool.setConfiguration(input.underlyingAsset, currentConfig.data);

    emit ReserveInitialized(
      input.underlyingAsset,
      depositTokenProxyAddress,
      stableDebtTokenProxyAddress,
      variableDebtTokenProxyAddress,
      input.strategy
    );
  }

  function updateDepositToken(UpdatePoolTokenInput calldata input) external onlyPoolAdmin {
    address token = pool.getReserveData(input.asset).depositTokenAddress;

    _updatePoolToken(input, token);
    emit DepositTokenUpgraded(input.asset, token, input.implementation);
  }

  function updateStableDebtToken(UpdatePoolTokenInput calldata input) external onlyPoolAdmin {
    address token = pool.getReserveData(input.asset).stableDebtTokenAddress;

    _updatePoolToken(input, token);
    emit StableDebtTokenUpgraded(input.asset, token, input.implementation);
  }

  function updateVariableDebtToken(UpdatePoolTokenInput calldata input) external onlyPoolAdmin {
    address token = pool.getReserveData(input.asset).variableDebtTokenAddress;

    _updatePoolToken(input, token);
    emit VariableDebtTokenUpgraded(input.asset, token, input.implementation);
  }

  function _updatePoolToken(UpdatePoolTokenInput calldata input, address token) private {
    (, , , uint256 decimals, ) = pool.getConfiguration(input.asset).getParamsMemory();

    PoolTokenConfig memory config =
      PoolTokenConfig({
        pool: address(pool),
        treasury: input.treasury,
        underlyingAsset: input.asset
      });

    bytes memory encodedCall =
      abi.encodeWithSelector(
        IInitializablePoolToken.initialize.selector,
        config,
        input.name,
        input.symbol,
        decimals,
        input.params
      );

    IProxy(token).upgradeToAndCall(input.implementation, encodedCall);
  }

  function implementationOf(address token) external view returns (address) {
    return _getProxyImplementation(IProxy(token));
  }

  function enableBorrowingOnReserve(address asset, bool stableBorrowRateEnabled)
    public
    onlyPoolAdmin
  {
    DataTypes.ReserveData memory reserve = pool.getReserveData(asset);
    require(reserve.variableDebtTokenAddress != address(0), Errors.LPC_INVALID_CONFIGURATION);
    require(
      !stableBorrowRateEnabled || (reserve.stableDebtTokenAddress != address(0)),
      Errors.LPC_INVALID_CONFIGURATION
    );

    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setBorrowingEnabled(true);
    currentConfig.setStableRateBorrowingEnabled(stableBorrowRateEnabled);

    pool.setConfiguration(asset, currentConfig.data);

    emit BorrowingEnabledOnReserve(asset, stableBorrowRateEnabled);
  }

  function disableBorrowingOnReserve(address asset) public onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setBorrowingEnabled(false);

    pool.setConfiguration(asset, currentConfig.data);
    emit BorrowingDisabledOnReserve(asset);
  }

  /**
   * @dev Configures the reserve collateralization parameters
   * all the values are expressed in percentages with two decimals of precision. A valid value is 10000, which means 100.00%
   * @param asset The address of the underlying asset of the reserve
   * @param ltv The loan to value of the asset when used as collateral
   * @param liquidationThreshold The threshold at which loans using this asset as collateral will be considered undercollateralized
   * @param liquidationBonus The bonus liquidators receive to liquidate this asset. The values is always above 100%. A value of 105%
   * means the liquidator will receive a 5% bonus
   **/
  function configureReserveAsCollateral(
    address asset,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus
  ) public onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    //validation of the parameters: the LTV can
    //only be lower or equal than the liquidation threshold
    //(otherwise a loan against the asset would cause instantaneous liquidation)
    require(ltv <= liquidationThreshold, Errors.LPC_INVALID_CONFIGURATION);

    if (liquidationThreshold != 0) {
      //liquidation bonus must be bigger than 100.00%, otherwise the liquidator would receive less
      //collateral than needed to cover the debt
      require(
        liquidationBonus > PercentageMath.PERCENTAGE_FACTOR,
        Errors.LPC_INVALID_CONFIGURATION
      );

      //if threshold * bonus is less than PERCENTAGE_FACTOR, it's guaranteed that at the moment
      //a loan is taken there is enough collateral available to cover the liquidation bonus
      require(
        liquidationThreshold.percentMul(liquidationBonus) <= PercentageMath.PERCENTAGE_FACTOR,
        Errors.LPC_INVALID_CONFIGURATION
      );
    } else {
      require(liquidationBonus == 0, Errors.LPC_INVALID_CONFIGURATION);
      //if the liquidation threshold is being set to 0,
      // the reserve is being disabled as collateral. To do so,
      //we need to ensure no liquidity is deposited
      _checkNoLiquidity(asset);
    }

    currentConfig.setLtv(ltv);
    currentConfig.setLiquidationThreshold(liquidationThreshold);
    currentConfig.setLiquidationBonus(liquidationBonus);

    pool.setConfiguration(asset, currentConfig.data);

    emit CollateralConfigurationChanged(asset, ltv, liquidationThreshold, liquidationBonus);
  }

  function enableReserveStableRate(address asset) external onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setStableRateBorrowingEnabled(true);

    pool.setConfiguration(asset, currentConfig.data);

    emit StableRateEnabledOnReserve(asset);
  }

  function disableReserveStableRate(address asset) external onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setStableRateBorrowingEnabled(false);

    pool.setConfiguration(asset, currentConfig.data);

    emit StableRateDisabledOnReserve(asset);
  }

  function activateReserve(address asset) external onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setActive(true);

    pool.setConfiguration(asset, currentConfig.data);

    emit ReserveActivated(asset);
  }

  function deactivateReserve(address asset) external onlyPoolAdmin {
    _checkNoLiquidity(asset);

    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setActive(false);

    pool.setConfiguration(asset, currentConfig.data);

    emit ReserveDeactivated(asset);
  }

  /// @dev Freezes a reserve. A frozen reserve doesn't allow any new deposit, borrow or rate swap
  /// but allows repayments, liquidations, rate rebalances and withdrawals
  function freezeReserve(address asset) external onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setFrozen(true);

    pool.setConfiguration(asset, currentConfig.data);

    emit ReserveFrozen(asset);
  }

  function unfreezeReserve(address asset) external onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setFrozen(false);

    pool.setConfiguration(asset, currentConfig.data);

    emit ReserveUnfrozen(asset);
  }

  function setReserveFactor(address asset, uint256 reserveFactor) public onlyPoolAdmin {
    DataTypes.ReserveConfigurationMap memory currentConfig = pool.getConfiguration(asset);

    currentConfig.setReserveFactor(reserveFactor);

    pool.setConfiguration(asset, currentConfig.data);

    emit ReserveFactorChanged(asset, reserveFactor);
  }

  function setReserveStrategy(
    address asset,
    address strategy,
    bool isExternal
  ) external onlyPoolAdmin {
    require(strategy != address(0) || isExternal);
    pool.setReserveStrategy(asset, strategy, isExternal);
    emit ReserveStrategyChanged(asset, strategy, isExternal);
  }

  function _initTokenWithProxy(address impl, bytes memory initParams) internal returns (address) {
    return address(_remoteAcl.createProxy(address(this), impl, initParams));
  }

  function _checkNoLiquidity(address asset) internal view {
    DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);

    uint256 availableLiquidity = IERC20(asset).balanceOf(reserveData.depositTokenAddress);

    require(
      availableLiquidity == 0 && reserveData.currentLiquidityRate == 0,
      Errors.LPC_RESERVE_LIQUIDITY_NOT_0
    );
  }

  function configureReserves(ConfigureReserveInput[] calldata inputParams) external onlyPoolAdmin {
    for (uint256 i = 0; i < inputParams.length; i++) {
      configureReserveAsCollateral(
        inputParams[i].asset,
        inputParams[i].baseLTV,
        inputParams[i].liquidationThreshold,
        inputParams[i].liquidationBonus
      );

      if (inputParams[i].borrowingEnabled) {
        enableBorrowingOnReserve(inputParams[i].asset, inputParams[i].stableBorrowingEnabled);
      } else {
        disableBorrowingOnReserve(inputParams[i].asset);
      }
      setReserveFactor(inputParams[i].asset, inputParams[i].reserveFactor);
    }
  }
}

interface ICombinedPool is ILendingPoolForTokens, IManagedLendingPool {}