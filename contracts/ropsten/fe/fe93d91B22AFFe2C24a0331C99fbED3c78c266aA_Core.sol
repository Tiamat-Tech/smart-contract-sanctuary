// SPDX-License-Identifier: MIT

import './storage/CoreStorage.sol';
import './interfaces/ICore.sol';
import '../managers/interfaces/IIncentiveManager.sol';
import '../managers/interfaces/ILoanManager.sol';
import '../managers/interfaces/ILiquidationManager.sol';
import '../pool/interfaces/IPool.sol';
import '../pool/interfaces/IDebtToken.sol';
import './libraries/ERC20Metadata.sol';
import './libraries/Factory.sol';
import './logic/Validation.sol';
import './logic/Index.sol';
import './logic/Rate.sol';
import './logic/Treasury.sol';

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

pragma solidity 0.8.4;

/// @title Core
/// @notice ELYFI has various contract interactions centered on the Core contract.
/// Several tokens are issued or destroyed to indicate the status of participants,
/// and all issuance and burn processes are carried out through the Core contract.
/// The depositor and borrower should approve the ELYFI core contract to move their AssetBond token
/// or ERC20 tokens on their behalf.
contract Core is ICore, CoreStorage {
  using SafeERC20 for IERC20;
  using Index for PoolData;
  using Validation for PoolData;
  using Rate for PoolData;
  using Treasury for PoolData;
  using Math for uint256;

  constructor(IProtocolAddressProvider protocolAddressProvider, address interestRateModel) {
    _protocolAddressProvider = protocolAddressProvider;
    _interestRateModel = interestRateModel;
  }

  /// ************** Modifiers ************* ///

  modifier onlyGuardian() {
    if (msg.sender != _protocolAddressProvider.getGuardian()) revert OnlyGuardian();
    _;
  }

  modifier onlyGovernance() {
    if (msg.sender != _protocolAddressProvider.getGovernance()) revert OnlyGovernance();
    _;
  }

  modifier onlyCouncil() {
    if (msg.sender != _protocolAddressProvider.getCouncil()) revert OnlyCouncil();
    _;
  }

  /// ************** User Interactions ************* ///

  /// @inheritdoc ICore
  /// @custom:check - make sure that pool is active and not paused
  /// @custom:check - `amount` is not 0
  /// @custom:effect - update interest rate and pool state
  /// @custom:interaction - `asset.safeTransferFrom`
  ///   - transfer underlying asset from `msg.sender` to `pool`
  /// @custom:interaction - call `pool.mint`
  ///   - mint poolToken to `account`
  /// @custom:interaction - `incentiveManager.updateUserIncentive`
  ///   - update user incentive
  /// @custom:interaction emit `Deposit` event
  function deposit(
    address asset,
    address account,
    uint256 amount
  ) external override {
    PoolData storage poolData = _poolData[asset];

    poolData.validateDeposit(amount);

    uint256 newIndex = poolData.updatePoolIndex(asset);

    poolData.updateRates(asset, address(_interestRateModel), amount, 0);

    address poolAddress = poolData.poolAddress;

    IERC20(asset).safeTransferFrom(msg.sender, poolAddress, amount);

    IPool(poolAddress).mint(account, amount, newIndex);

    emit Deposit(asset, account, amount);
  }

  /// @inheritdoc ICore
  /// @custom:check - make sure that pool is active and not paused
  /// @custom:check - `amount` is not 0
  /// @custom:check - `amount` exceeds pool available liquidity
  /// @custom:effect - update interest rate and pool state
  /// @custom:interaction - call `pool.burnAndTransferAsset`
  ///   - burn poolToken from `msg.sender` and transfer underlying asset to `account`
  /// @custom:interaction - emit `Withdraw` event
  function withdraw(
    address asset,
    address receiver,
    uint256 amount
  ) external override {
    PoolData storage poolData = _poolData[asset];

    address poolAddress = poolData.poolAddress;

    uint256 userPoolTokenBalance = IPool(poolAddress).balanceOf(msg.sender);

    uint256 amountToWithdraw = amount;

    // if amount is equal to uint(-1), the user wants to redeem everything
    if (amount == type(uint256).max) {
      amountToWithdraw = userPoolTokenBalance;
    }

    uint256 newIndex = poolData.updatePoolIndex(asset);

    poolData.validateWithdraw(asset, amountToWithdraw, userPoolTokenBalance);

    uint256 stabilityFee = poolData.getStabilityFee(
      asset,
      _protocolAddressProvider.getProtocolTreasury(),
      amountToWithdraw
    );

    poolData.updateRates(asset, address(_interestRateModel), stabilityFee, amountToWithdraw);

    if (stabilityFee != 0) {
      IPool(poolData.poolAddress).mintToProtocolTreasury(stabilityFee, newIndex);
    }

    IPool(poolAddress).burnAndTransferAsset(
      msg.sender,
      receiver,
      amountToWithdraw,
      amountToWithdraw - stabilityFee,
      newIndex
    );

    emit Withdraw(asset, msg.sender, receiver, amountToWithdraw);
  }

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the council governance contract
  /// @custom:check - make sure that pool is active and not paused
  /// @custom:check - `amount` should be less than `asset.balanceOf(pool)`
  /// @custom:check - call `onERC721Received` and check that erc721 is whitelisted one
  /// @custom:effect - update interest rate and pool state
  /// @custom:interaction - call `_accrueProtocolTreasury`
  ///   - accrue protocol treasury
  /// @custom:interaction - call `loanManager.beginLoan`
  ///   - hash loan and save loan data in the loanManager
  /// @custom:interaction - call `debtToken.mint`
  ///   - mint debt token to borrower
  /// @custom:interaction - call `pool.transferAsset`
  ///   - transfer loan principal to `receiver`
  /// @custom:interaction - call `collateral.safeTransferFrom`
  ///   - transfer asset token from `borrower` to `receiver`
  ///   - asset token to be collateralized should be approved for core `address(this)`
  /// @custom:interaction - emit `Borrow` event
  function borrow(
    address asset,
    address collateral,
    address borrower,
    address receiver,
    uint256 tokenId,
    uint256 loanPrincipal,
    uint256 loanDuration,
    string memory description
  ) external override onlyCouncil {
    PoolData storage poolData = _poolData[asset];

    bytes32 descriptionHash = keccak256(bytes(description));

    uint256 poolRemainingLiquidity = IERC20(asset).balanceOf(poolData.poolAddress);
    uint256 loanInterestRate = poolData.borrowAPY;

    poolData.validateBorrow(loanPrincipal, poolRemainingLiquidity);

    uint256 interestIndex = poolData.getPoolTokenInterestIndex();

    poolData.accrueLoanFee(interestIndex);

    poolData.updatePoolIndex(asset);

    ILoanManager(_protocolAddressProvider.getLoanManager()).beginLoan(
      borrower,
      asset,
      collateral,
      tokenId,
      loanPrincipal,
      loanDuration,
      loanInterestRate,
      descriptionHash
    );

    IDebtToken(poolData.debtTokenAddress).mint(borrower, loanPrincipal, loanInterestRate);

    poolData.updateRates(asset, address(_interestRateModel), 0, loanPrincipal);

    IPool(poolData.poolAddress).transferAsset(receiver, loanPrincipal);

    IERC721(collateral).safeTransferFrom(borrower, address(this), tokenId);

    emit Borrow(
      asset,
      collateral,
      borrower,
      receiver,
      tokenId,
      loanPrincipal,
      loanInterestRate,
      loanDuration,
      description
    );
  }

  /// @inheritdoc ICore
  /// @custom:check - call `loanManager.repayLoan`
  ///   - loan must not be `DEFAULTED`
  /// @custom:effect - update interest rate and pool state
  ///   - burn debt token from `borrower` and transfer
  /// @custom:interaction call `loanManager.repayLoan`
  ///   - change loan state to `END`
  /// @custom:interaction - call `_accrueProtocolTreasury`
  ///   - accrue protocol treasury
  /// @custom:interaction - call `asset.safeTransferFrom`
  ///   - transfer principal and interest from `msg.sender` to `pool`
  /// @custom:interaction - call `debtToken.burn`
  ///   - burn debt token from `borrower`
  /// @custom:interaction - call `collateral.safeTransferFrom`
  ///   - transfer collateralized asset token from the core contract to `borrower`
  function repay(
    address asset,
    address collateral,
    address borrower,
    uint256 tokenId,
    bytes32 descriptionHash
  ) external override {
    PoolData storage poolData = _poolData[asset];

    (uint256 loanState, uint256 repayAmount, uint256 loanInterestRate) = ILoanManager(
      _protocolAddressProvider.getLoanManager()
    ).repayLoan(borrower, asset, collateral, tokenId, descriptionHash);

    poolData.validateRepay(loanState);

    uint256 interestIndex = poolData.getPoolTokenInterestIndex();

    poolData.accrueLoanFee(interestIndex);

    poolData.updatePoolIndex(asset);

    IERC20(asset).safeTransferFrom(msg.sender, poolData.poolAddress, repayAmount);

    IDebtToken(poolData.debtTokenAddress).burn(borrower, repayAmount);

    poolData.updateRates(asset, address(_interestRateModel), repayAmount, 0);

    IERC721(collateral).safeTransferFrom(address(this), borrower, tokenId);

    emit Repay(
      asset,
      collateral,
      borrower,
      msg.sender,
      tokenId,
      repayAmount,
      loanInterestRate,
      block.timestamp
    );
  }

  /// @inheritdoc ICore
  /// @custom:check - call `loanManager.repayLoan`
  ///   - loan must be `DEFAULTED`
  /// @custom:effect - update interest rate and pool state
  ///   - burn debt token from `borrower` and transfer
  /// @custom:interaction - call `loanManager.repayLoan`
  ///   - change loan state to `END`
  /// @custom:interaction - call `liquidationManager.liquidate`
  ///   - transfer principal and interest from `msg.sender` to `pool` by LiquidationManager
  /// @custom:interaction - call `collateral.safeTransferFrom`
  ///   - transfer collateralized asset token to `liquidationManager`
  /// @custom:interaction - call `debtToken.burn`
  ///   - burn debt token from `borrower`
  function liquidate(
    address asset,
    address collateral,
    address borrower,
    uint256 tokenId,
    bytes32 descriptionHash
  ) external override {
    PoolData storage poolData = _poolData[asset];

    uint256 previousRemainingLiquiditiy = IERC20(asset).balanceOf(poolData.poolAddress);

    uint256 loanId = ILoanManager(_protocolAddressProvider.getLoanManager()).hashLoan(
      borrower,
      asset,
      collateral,
      msg.sender,
      tokenId,
      descriptionHash
    );

    (uint256 loanState, uint256 repayAmount, uint256 loanInterestRate) = ILoanManager(
      _protocolAddressProvider.getLoanManager()
    ).repayLoan(borrower, asset, collateral, tokenId, descriptionHash);

    ILiquidationManager(_protocolAddressProvider.getLiquidationManager()).liquidate(
      asset,
      poolData.poolAddress,
      msg.sender,
      loanId,
      repayAmount
    );

    {
      uint256 remainingLiquiditiy = IERC20(asset).balanceOf(poolData.poolAddress);

      poolData.validateLiquidate(
        loanState,
        repayAmount,
        previousRemainingLiquiditiy,
        remainingLiquiditiy
      );
    }

    uint256 interestIndex = poolData.getPoolTokenInterestIndex();

    poolData.accrueLoanFee(interestIndex);

    poolData.updatePoolIndex(asset);

    IDebtToken(poolData.debtTokenAddress).burn(borrower, repayAmount);

    poolData.updateRates(asset, address(_interestRateModel), repayAmount, 0);

    IERC721(collateral).safeTransferFrom(
      address(this),
      _protocolAddressProvider.getLiquidationManager(),
      tokenId
    );

    emit Liquidate(
      asset,
      collateral,
      borrower,
      msg.sender,
      tokenId,
      repayAmount,
      loanInterestRate,
      block.timestamp
    );
  }

  /// @inheritdoc ICore
  /// @custom:interaction - call `_accrueProtocolTreasury`
  ///   - mint pool token the amount of debt token accrued multiplied by the pool factor
  function accrueProtocolTreasury(address asset) external override {
    PoolData storage poolData = _poolData[asset];

    uint256 currentIndex = poolData.getPoolTokenInterestIndex();

    poolData.accrueLoanFee(currentIndex);

    IDebtToken(poolData.debtTokenAddress).updateDebtTokenState();
  }

  /// ************** Governance Functions ************* ///

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the governance contract
  /// @custom:effect - set new `_interestRateModel`
  /// @custom:interaction - emit `UpdateInterestRateModel` event
  function updateInterestRateModel(address interestRateModel) external override onlyGovernance {
    address previousInterestRateModel = _interestRateModel;
    _interestRateModel = interestRateModel;
    emit UpdateInterestRateModel(previousInterestRateModel, interestRateModel);
  }

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the governance.
  /// @custom:effect - set `_allowedAssetToken[assetToken]` to true
  /// @custom:interaction - emit `AllowAssetToken` event
  function allowAssetToken(address assetToken) external override onlyGovernance {
    _allowedAssetToken[assetToken] = true;
    emit AllowAssetToken(assetToken);
  }

  /// @inheritdoc ICore
  /// @custom:check - Make sure that `msg.sender` is core contract
  /// @custom:check - PoolData with `asset` does not already exist
  /// @custom:effect - Deploy Pool and DebtToken contract and store its data
  /// @custom:interaction - call `incentiveManager.setIncentivePlan`
  ///   - set incentive plan with given allocation for given asset
  /// @custom:interaction - emit `AddNewPool` event
  function addNewPool(
    address asset,
    uint256 incentiveAllocation,
    uint256 poolFactor
  ) external override {
    // use temporary storage to allow pool and debt token contract to call ERC20Metadata
    _assetToAdd = asset;
    (address poolAddress, address debtTokenAddress) = Factory.createPool(asset);
    _assetToAdd = address(0);

    PoolData memory newPoolData = PoolData({
      poolInterestIndex: Math.ray(),
      borrowAPY: 0,
      depositAPY: 0,
      lastUpdateTimestamp: block.timestamp,
      poolFactor: poolFactor,
      poolAddress: poolAddress,
      debtTokenAddress: debtTokenAddress,
      isPaused: false,
      isActivated: true
    });

    _poolData[asset] = newPoolData;

    IIncentiveManager(_protocolAddressProvider.getIncentiveManager()).setIncentivePlan(
      poolAddress,
      incentiveAllocation
    );

    emit AddNewPool(poolAddress, debtTokenAddress);
  }

  /// ************** Guardian Functions ************* ///

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the guardian address
  /// @custom:effect - set `poolData[asset].isActive` to true
  /// @custom:interaction - emit `ActivatePool` event
  function activatePool(address asset) external override onlyGuardian {
    PoolData storage poolData = _poolData[asset];
    poolData.isActivated = true;
    emit ActivatePool(asset, block.timestamp);
  }

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the guardian address
  /// @custom:effect - set `poolData[asset].isActive` to false
  /// @custom:interaction - emit `DeactivatePool` event
  function deactivatePool(address asset) external override onlyGuardian {
    PoolData storage poolData = _poolData[asset];
    poolData.isActivated = false;
    emit DeactivatePool(asset, block.timestamp);
  }

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the guardian address
  /// @custom:effect - set `poolData[asset].isPaused` to true
  /// @custom:interaction - emit `PausePool` event
  function pausePool(address asset) external override onlyGuardian {
    PoolData storage poolData = _poolData[asset];
    poolData.isPaused = true;
    emit PausePool(asset, block.timestamp);
  }

  /// @inheritdoc ICore
  /// @custom:check - make sure that `msg.sender` is the guardian address
  /// @custom:effect - set `poolData[asset].isPaused` to false
  /// @custom:interaction - emit `UnpausePool` event
  function unpausePool(address asset) external override onlyGuardian {
    PoolData storage poolData = _poolData[asset];
    poolData.isPaused = false;
    emit UnpausePool(asset, block.timestamp);
  }

  /// ************** View Functions ************* ///

  /// @inheritdoc ICore
  function getPoolData(address asset)
    external
    view
    override
    returns (
      uint256 poolInterestIndex,
      uint256 borrowAPY,
      uint256 depositAPY,
      uint256 lastUpdateTimestamp,
      uint256 poolFactor,
      address poolAddress,
      address debtTokenAddress,
      bool isPaused,
      bool isActivated
    )
  {
    PoolData storage poolData = _poolData[asset];

    poolInterestIndex = poolData.poolInterestIndex;
    borrowAPY = poolData.borrowAPY;
    depositAPY = poolData.depositAPY;
    lastUpdateTimestamp = poolData.lastUpdateTimestamp;
    poolFactor = poolData.poolFactor;
    poolAddress = poolData.poolAddress;
    debtTokenAddress = poolData.debtTokenAddress;
    isPaused = poolData.isPaused;
    isActivated = poolData.isActivated;
  }

  /// @inheritdoc ICore
  function getPoolInterestIndex(address asset)
    external
    view
    override
    returns (uint256 poolInterestIndex)
  {
    PoolData storage poolData = _poolData[asset];

    poolInterestIndex = poolData.getPoolTokenInterestIndex();
  }

  /// @inheritdoc ICore
  function getProtocolAddressProvider()
    external
    view
    override
    returns (address protocolAddressProvider)
  {
    protocolAddressProvider = address(_protocolAddressProvider);
  }

  /// @inheritdoc ICore
  function getInterestRateModel() external view override returns (address interestRateModel) {
    interestRateModel = _interestRateModel;
  }

  /// @inheritdoc ICore
  function getProtocolTreasury() external view override returns (address protocolTreasury) {
    protocolTreasury = _protocolAddressProvider.getProtocolTreasury();
  }

  /// @inheritdoc ICore
  function getAssetTokenAllowed(address assetToken) external view override returns (bool allowed) {
    return _allowedAssetToken[assetToken];
  }

  /// @inheritdoc ICore
  function getAssetAdded() external view override returns (address asset) {
    asset = _assetToAdd;
  }

  /// @inheritdoc ICore
  function getERC20NameSafe(address asset) external view override returns (string memory name) {
    name = ERC20Metadata.tokenName(asset);
  }

  /// @inheritdoc ICore
  function getERC20SymbolSafe(address asset) external view override returns (string memory symbol) {
    symbol = ERC20Metadata.tokenSymbol(asset);
  }

  /// @notice Upon receiving an allowed asset token, checks if the asset token is listed
  /// @inheritdoc IERC721Receiver
  /// @custom:check - make sure that `msg.sender` is listed asset token contract.
  function onERC721Received(
    address,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    if (!_allowedAssetToken[msg.sender]) revert NotAllowedAssetToken();

    return this.onERC721Received.selector;
  }
}