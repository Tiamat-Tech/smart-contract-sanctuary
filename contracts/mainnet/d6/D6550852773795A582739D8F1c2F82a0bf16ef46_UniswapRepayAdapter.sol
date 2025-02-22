// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import '../../interfaces/IFlashLoanAddressProvider.sol';
import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../protocol/libraries/types/DataTypes.sol';
import '../../dependencies/openzeppelin/contracts/SafeMath.sol';
import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import './BaseUniswapAdapter.sol';

/// @notice Performs a repay of a debt with collateral via Uniswap V2
contract UniswapRepayAdapter is BaseUniswapAdapter {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct RepayParams {
    address collateralAsset;
    uint256 collateralAmount;
    uint256 rateMode;
    PermitSignature permitSignature;
    bool useEthPath;
  }

  constructor(IFlashLoanAddressProvider addressesProvider, IUniswapV2Router02ForAdapter uniswapRouter)
    BaseUniswapAdapter(addressesProvider, uniswapRouter)
  {}

  /**
   * @dev Uses the received funds from the flash loan to repay a debt on the protocol on behalf of the user. Then pulls
   * the collateral from the user and swaps it to the debt asset to repay the flash loan.
   * The user should give this contract allowance to pull deposit tokens in order to withdraw the underlying asset, swap it
   * and repay the flash loan.
   * Supports only one asset on the flash loan.
   * @param assets Address of debt asset
   * @param amounts Amount of the debt to be repaid
   * @param premiums Fee of the flash loan
   * @param initiator Address of the user
   * @param params Additional variadic field to include extra params. Expected parameters:
   *   address collateralAsset Address of the reserve to be swapped
   *   uint256 collateralAmount Amount of reserve to be swapped
   *   uint256 rateMode Rate modes of the debt to be repaid
   *   uint256 permitAmount Amount for the permit signature
   *   uint256 deadline Deadline for the permit signature
   *   uint8 v V param for the permit signature
   *   bytes32 r R param for the permit signature
   *   bytes32 s S param for the permit signature
   */
  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external override returns (bool) {
    require(msg.sender == address(LENDING_POOL), 'CALLER_MUST_BE_LENDING_POOL');

    RepayParams memory decodedParams = _decodeParams(params);

    _swapAndRepay(
      decodedParams.collateralAsset,
      assets[0],
      amounts[0],
      decodedParams.collateralAmount,
      decodedParams.rateMode,
      initiator,
      premiums[0],
      decodedParams.permitSignature,
      decodedParams.useEthPath
    );

    return true;
  }

  /**
   * @dev Swaps the user collateral for the debt asset and then repay the debt on the protocol on behalf of the user
   * without using flash loans. This method can be used when the temporary transfer of the collateral asset to this
   * contract does not affect the user position.
   * The user should give this contract allowance to pull deposit tokens in order to withdraw the underlying asset
   * @param collateralAsset Address of asset to be swapped
   * @param debtAsset Address of debt asset
   * @param collateralAmount Amount of the collateral to be swapped
   * @param debtRepayAmount Amount of the debt to be repaid
   * @param debtRateMode Rate mode of the debt to be repaid
   * @param permitSignature struct containing the permit signature
   * @param useEthPath struct containing the permit signature

   */
  function swapAndRepay(
    address collateralAsset,
    address debtAsset,
    uint256 collateralAmount,
    uint256 debtRepayAmount,
    uint256 debtRateMode,
    PermitSignature calldata permitSignature,
    bool useEthPath
  ) external {
    DataTypes.ReserveData memory collateralReserveData = _getReserveData(collateralAsset);
    DataTypes.ReserveData memory debtReserveData = _getReserveData(debtAsset);

    address debtToken = DataTypes.InterestRateMode(debtRateMode) == DataTypes.InterestRateMode.STABLE
      ? debtReserveData.stableDebtTokenAddress
      : debtReserveData.variableDebtTokenAddress;

    uint256 currentDebt = IERC20(debtToken).balanceOf(msg.sender);
    uint256 amountToRepay = debtRepayAmount <= currentDebt ? debtRepayAmount : currentDebt;

    if (collateralAsset != debtAsset) {
      uint256 maxCollateralToSwap = collateralAmount;
      if (amountToRepay < debtRepayAmount) {
        maxCollateralToSwap = maxCollateralToSwap.mul(amountToRepay).div(debtRepayAmount);
      }

      // Get exact collateral needed for the swap to avoid leftovers
      uint256[] memory amounts = _getAmountsIn(collateralAsset, debtAsset, amountToRepay, useEthPath);
      require(amounts[0] <= maxCollateralToSwap, 'slippage too high');

      // Pull depositTokens from user
      _pullDepositToken(
        collateralAsset,
        collateralReserveData.depositTokenAddress,
        msg.sender,
        amounts[0],
        permitSignature
      );

      // Swap collateral for debt asset
      _swapTokensForExactTokens(collateralAsset, debtAsset, amounts[0], amountToRepay, useEthPath);
    } else {
      // Pull depositTokens from user
      _pullDepositToken(
        collateralAsset,
        collateralReserveData.depositTokenAddress,
        msg.sender,
        amountToRepay,
        permitSignature
      );
    }

    // Repay debt. Approves 0 first to comply with tokens that implement the anti frontrunning approval fix
    IERC20(debtAsset).safeApprove(address(LENDING_POOL), 0);
    IERC20(debtAsset).safeApprove(address(LENDING_POOL), amountToRepay);
    LENDING_POOL.repay(debtAsset, amountToRepay, debtRateMode, msg.sender);
  }

  /**
   * @dev Perform the repay of the debt, pulls the initiator collateral and swaps to repay the flash loan
   *
   * @param collateralAsset Address of token to be swapped
   * @param debtAsset Address of debt token to be received from the swap
   * @param amount Amount of the debt to be repaid
   * @param collateralAmount Amount of the reserve to be swapped
   * @param rateMode Rate mode of the debt to be repaid
   * @param initiator Address of the user
   * @param premium Fee of the flash loan
   * @param permitSignature struct containing the permit signature
   */
  function _swapAndRepay(
    address collateralAsset,
    address debtAsset,
    uint256 amount,
    uint256 collateralAmount,
    uint256 rateMode,
    address initiator,
    uint256 premium,
    PermitSignature memory permitSignature,
    bool useEthPath
  ) internal {
    DataTypes.ReserveData memory collateralReserveData = _getReserveData(collateralAsset);

    // Repay debt. Approves for 0 first to comply with tokens that implement the anti frontrunning approval fix.
    IERC20(debtAsset).safeApprove(address(LENDING_POOL), 0);
    IERC20(debtAsset).safeApprove(address(LENDING_POOL), amount);
    uint256 repaidAmount = IERC20(debtAsset).balanceOf(address(this));
    LENDING_POOL.repay(debtAsset, amount, rateMode, initiator);
    repaidAmount = repaidAmount.sub(IERC20(debtAsset).balanceOf(address(this)));

    if (collateralAsset != debtAsset) {
      uint256 maxCollateralToSwap = collateralAmount;
      if (repaidAmount < amount) {
        maxCollateralToSwap = maxCollateralToSwap.mul(repaidAmount).div(amount);
      }

      uint256 neededForFlashLoanDebt = repaidAmount.add(premium);
      uint256[] memory amounts = _getAmountsIn(collateralAsset, debtAsset, neededForFlashLoanDebt, useEthPath);
      require(amounts[0] <= maxCollateralToSwap, 'slippage too high');

      // Pull depositTokens from user
      _pullDepositToken(
        collateralAsset,
        collateralReserveData.depositTokenAddress,
        initiator,
        amounts[0],
        permitSignature
      );

      // Swap collateral asset to the debt asset
      _swapTokensForExactTokens(collateralAsset, debtAsset, amounts[0], neededForFlashLoanDebt, useEthPath);
    } else {
      // Pull depositTokens from user
      _pullDepositToken(
        collateralAsset,
        collateralReserveData.depositTokenAddress,
        initiator,
        repaidAmount.add(premium),
        permitSignature
      );
    }

    // Repay flashloan. Approves for 0 first to comply with tokens that implement the anti frontrunning approval fix.
    IERC20(debtAsset).safeApprove(address(LENDING_POOL), 0);
    IERC20(debtAsset).safeApprove(address(LENDING_POOL), amount.add(premium));
  }

  /**
   * @dev Decodes debt information encoded in the flash loan params
   * @param params Additional variadic field to include extra params. Expected parameters:
   *   address collateralAsset Address of the reserve to be swapped
   *   uint256 collateralAmount Amount of reserve to be swapped
   *   uint256 rateMode Rate modes of the debt to be repaid
   *   uint256 permitAmount Amount for the permit signature
   *   uint256 deadline Deadline for the permit signature
   *   uint8 v V param for the permit signature
   *   bytes32 r R param for the permit signature
   *   bytes32 s S param for the permit signature
   *   bool useEthPath use WETH path route
   * @return RepayParams struct containing decoded params
   */
  function _decodeParams(bytes memory params) internal pure returns (RepayParams memory) {
    (
      address collateralAsset,
      uint256 collateralAmount,
      uint256 rateMode,
      uint256 permitAmount,
      uint256 deadline,
      uint8 v,
      bytes32 r,
      bytes32 s,
      bool useEthPath
    ) = abi.decode(params, (address, uint256, uint256, uint256, uint256, uint8, bytes32, bytes32, bool));

    return
      RepayParams(
        collateralAsset,
        collateralAmount,
        rateMode,
        PermitSignature(permitAmount, deadline, v, r, s),
        useEthPath
      );
  }
}