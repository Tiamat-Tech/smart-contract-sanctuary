// SPDX-License-Identifier: AGPLv3
pragma solidity >=0.6.0 <0.7.0;

import "./common/DecimalConstants.sol";
import "./common/Controllable.sol";
import "./interfaces/ILifeGuard.sol";
import "./interfaces/IBuoy.sol";
import "./interfaces/IDepositHandler.sol";
import "./interfaces/IToken.sol";
import "./interfaces/IPnL.sol";
import "./interfaces/IInsurance.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/// @notice Entry point for deposits into Gro protocol - User deposits can be done with one or
///     multiple assets, being more expensive gas wise for each additional asset that is deposited.
///     The deposits are treated differently depending on size:
///         1) sardine - the smallest type of deposit, deemed to not affect the system exposure, and
///            is deposited directly into the system - Curve vault is used to price the deposit (buoy)
///         2) tuna - mid sized deposits, will be swapped to least exposed vault asset using Curve's
///            exchange function (lifeguard). Targeting the desired asset (single sided deposit
///            against the least exposed stablecoin) minimizes slippage as it doesn't need to perform
///            any exchanges in the Curve pool
///         3) whale - the largest deposits - deposit will be distributed across all stablecoin vaults
///
///     Tuna and Whale deposits will go through the lifeguard, which in turn will perform all
///     necessary asset swaps.
contract DepositHandler is DecimalConstants, Controllable, IDepositHandler {
    uint256 public utilisationRatioLimitPwrd;
    IController ctrl;
    ILifeGuard lg;
    IBuoy buoy;
    IInsurance insurance;
    IVault[] vaults;
    uint256[] decimals;
    mapping(bool => IToken) gTokens;

    mapping(address => address) public override referral;
    mapping(uint256 => bool) public feeToken; // (USDT might have a fee)

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event LogNewUtilLimit(bool indexed pwrd, uint256 limit);
    event LogNewFeeToken(address indexed token, uint256 index);
    event LogNewDependencies(
        address controller, 
        address lifeguard, 
        address buoy, 
        address insurance,
        address pwrd,
        address gvt
    );
    event LogNewDeposit(
        address indexed user,
        address indexed referral,
        bool pwrd,
        uint256 usdAmount,
        uint256[] tokens
    );

    /// @notice Update protocol dependencies
    function setDependencies() external onlyGovernance {
        ctrl = _controller();
        address[] memory _vaults = ctrl.vaults();
        delete vaults;
        delete decimals;
        for (uint256 i; i < _vaults.length; i++) {
            IVault vault = IVault(_vaults[i]);
            decimals.push(uint256(10)**(IERC20Detailed(vault.token()).decimals()));
            vaults.push(vault);
        }
        lg = ILifeGuard(ctrl.lifeGuard());
        buoy = IBuoy(lg.getBuoy());
        insurance = IInsurance(ctrl.insurance());
        gTokens[true] = IToken(ctrl.gToken(true));
        gTokens[false] = IToken(ctrl.gToken(false));
        emit LogNewDependencies(
            address(ctrl), 
            address(lg), 
            address(buoy), 
            address(insurance), 
            address(gTokens[true]),
            address(gTokens[false])
        );
    }

    /// @notice Set the lower bound for when to stop accepting deposits for pwrd - this allows for a bit of legroom
    ///     for gvt to be sold (if this limit is reached, this contract only accepts deposits for gvt)
    /// @param _utilisationRatioLimitPwrd Lower limit for pwrd (%BP)
    function setUtilisationRatioLimitPwrd(uint256 _utilisationRatioLimitPwrd)
        external
        onlyGovernance
    {
        utilisationRatioLimitPwrd = _utilisationRatioLimitPwrd;
        emit LogNewUtilLimit(true, _utilisationRatioLimitPwrd);
    }

    /// @notice Some tokens might have fees associated with them (e.g. USDT)
    /// @param index Index (of system tokens) that could have fees
    function setFeeToken(uint256 index) external onlyGovernance {
        address token = ctrl.stablecoins()[index];
        require(token != address(0), 'setFeeToken: !invalid token');
        feeToken[index] = true;
        emit LogNewFeeToken(token, index);
    }

    /// @notice Entry when depositing for pwrd
    /// @param inAmounts Amount of each stablecoin deposited
    /// @param minAmount Minimum ammount to expect in return for deposit
    /// @param _referral Referral address (only useful for first deposit)
    function depositPwrd(
        uint256[] memory inAmounts,
        uint256 minAmount,
        address _referral
    ) external override whenNotPaused {
        depositGToken(inAmounts, minAmount, _referral, true);
    }

    /// @notice Entry when depositing for gvt
    /// @param inAmounts Amount of each stablecoin deposited
    /// @param minAmount Minimum ammount to expect in return for deposit
    /// @param _referral Referral address (only useful for first deposit)
    function depositGvt(
        uint256[] memory inAmounts,
        uint256 minAmount,
        address _referral
    ) external override whenNotPaused {
        depositGToken(inAmounts, minAmount, _referral, false);
    }

    /// @notice Deposit logic
    /// @param inAmounts Amount of each stablecoin deposited
    /// @param minAmount Minimum amount to expect in return for deposit
    /// @param _referral Referral address (only useful for first deposit)
    /// @param pwrd Pwrd or gvt (pwrd/gvt)
    function depositGToken(
        uint256[] memory inAmounts,
        uint256 minAmount,
        address _referral,
        bool pwrd
    ) private {
        // Flashloan preventation
        ctrl.eoaOnly(msg.sender);
        ctrl.preventFLABegin();
        require(minAmount > 0, "minAmount is 0");
        if (_referral != address(0) && referral[msg.sender] == address(0)) {
            referral[msg.sender] = _referral;
        }

        IToken gt = gTokens[pwrd];

        uint256 factor = gt.factor();
        uint256 roughUsd = roughUsd(inAmounts, decimals);

        // Make sure we don't increase the amount of pwrd above the utilization limit
        if (pwrd) {
            require(validGTokenIncrease(roughUsd), "exceeds utilisation limit");
        }

        (uint256 dollarAmount, uint256 _factor) = _deposit(pwrd, roughUsd, minAmount, inAmounts);
        if (_factor > 0) {
            factor = _factor;
        }

        gt.mint(msg.sender, factor, dollarAmount);
        // Update underlying assets held in pwrd/gvt
        IPnL(ctrl.pnl()).increaseGTokenLastAmount(address(gt), dollarAmount);

        emit LogNewDeposit(msg.sender, referral[msg.sender], pwrd, dollarAmount, inAmounts);
        ctrl.preventFLAEnd();
    }

    /// @notice Determine the size of the deposit, and route it accordingly:
    ///     sardine (small) - gets sent directly to the vault adapter
    ///     tuna (middle) - tokens get routed through lifeguard and exchanged to
    ///             target token (based on current vault exposure)
    ///     whale (large) - tokens get deposited into lifeguard Curve pool, withdraw
    ///             into target amounts and deposited across all vaults
    /// @param pwrd Pwrd or gvt
    /// @param roughUsd Estimated USD value of deposit, used to determine size
    /// @param minAmount Minimum amount to return (in Curve LP tokens)
    /// @param inAmounts Input token amounts
    function _deposit(
        bool pwrd,
        uint256 roughUsd,
        uint256 minAmount,
        uint256[] memory inAmounts
    ) private returns (uint256 dollarAmount, uint256 factor) {
        // If a large fish, transfer assets to lifeguard before determening what to do with them
        if (ctrl.isWhale(roughUsd, pwrd)) {
            for (uint256 i = 0; i < lg.N_COINS(); i++) {
                // Transfer token to target (lifeguard)
                if (inAmounts[i] > 0) {
                    IERC20 token = IERC20(lg.underlyingCoins(i));
                    if (feeToken[i]) {
                        // Separate logic for USDT
                        uint256 current = token.balanceOf(address(lg));
                        token.safeTransferFrom(msg.sender, address(lg), inAmounts[i]);
                        inAmounts[i] = token.balanceOf(address(lg)).sub(current);
                    } else {
                        token.safeTransferFrom(msg.sender, address(lg), inAmounts[i]);
                    }
                }
            }
            (dollarAmount, factor) = _invest(pwrd, inAmounts, roughUsd);
        } else {
            // If sardine, send the assets directly to the vault adapter
            for (uint256 i = 0; i < lg.N_COINS(); i++) {
                if (inAmounts[i] > 0) {
                    // Transfer token to vaultadaptor
                    IERC20 token = IERC20(lg.underlyingCoins(i));
                    address _vault = address(vaults[i]);
                    if (feeToken[i]) {
                        // Seperate logic for USDT
                        uint256 current = token.balanceOf(_vault);
                        token.safeTransferFrom(msg.sender, _vault, inAmounts[i]);
                        inAmounts[i] = token.balanceOf(_vault).sub(current);
                    } else {
                        token.safeTransferFrom(msg.sender, _vault, inAmounts[i]);
                    }
                    // Update vaultadaptor assets
                    vaults[i].updatePnL(inAmounts[i]);
                }
            }
            // Establish USD vault of deposit
            dollarAmount = buoy.stableToUsd(inAmounts, true);
        }
        require(dollarAmount >= buoy.lpToUsd(minAmount), "!minAmount");
    }

    /// @notice Determine how to handle the deposit - get stored vault deltas and indexes,
    ///     and determine if the deposit will be a tuna (deposits into least exposed vaults)
    ///        or a whale (spread across all three vaults)
    ///     Tuna - Deposit swaps all overexposed assets into least exposed asset before investing,
    ///         deposited assets into the two least exposed vaults
    ///     Whale - Deposits all assets into the lifeguard Curve pool, and withdraws
    ///         them in target allocation (insurance underlyingTokensPercents) amounts before
    ///        investing them into all vaults
    /// @param pwrd Pwrd or gvt
    /// @param _inAmounts Input token amounts
    /// @param roughUsd Estimated rough USD value of deposit
    function _invest(
        bool pwrd,
        uint256[] memory _inAmounts,
        uint256 roughUsd
    ) internal returns (uint256 dollarAmount, uint256 factor) {
        // Calculate asset distribution - for large deposits, we will want to spread the
        // assets across all stablecoin vaults to avoid overexposure, otherwise we only
        // ensure that the deposit doesn't target the most overexposed vault
        (, uint256[] memory vaultIndexes, uint256 _vaults) = insurance.getVaultDelta(roughUsd);
        if (_vaults < 3) {
            dollarAmount = lg.investSingle(_inAmounts, vaultIndexes[0], vaultIndexes[1]);
        } else {
            uint256 outAmount = lg.deposit(_inAmounts);
            uint256[] memory delta = insurance.calculateDepositDeltasOnAllVaults();
            dollarAmount = lg.invest(outAmount, delta);
            IPnL pnl = IPnL(ctrl.pnl());
            if (pnl.pnlTrigger()) {
                // Deposited assets is in lifeguard now and accounted into system total assets
                // Should remove this deposited assets to handle PnL, otherwise will distribute it between gvt and pwrd
                pnl.execPnL(dollarAmount);
                // GToken total assets is incorrect here because system total assets includes this deposited assets
                // Re-calculate factor based on PnL result instead of GToken total assets
                factor = gTokens[pwrd].factor();
            }
        }
    }

    /// @notice Check if it's OK to mint the specified amount of tokens, this affects
    ///     pwrds, as they have an upper bound set by the amount of gvt
    /// @param amount Amount of token to burn
    function validGTokenIncrease(uint256 amount) private view returns (bool) {
        return
            gTokens[false].totalAssets().mul(utilisationRatioLimitPwrd).div(
                PERCENTAGE_DECIMAL_FACTOR
            ) >= amount.add(gTokens[true].totalAssets());
    }

    /// @notice Give a USD estimate of the deposit - this is purely used to determine deposit size
    ///     and does not impact amount of tokens minted
    /// @param inAmounts Amount of tokens deposited
    /// @param _decimals Decimals for token denoted in (10**X)
    function roughUsd(uint256[] memory inAmounts, uint256[] memory _decimals)
        private
        pure
        returns (uint256 usdAmount)
    {
        for (uint256 i; i < inAmounts.length; i++) {
            if (inAmounts[i] > 0) {
                usdAmount = usdAmount.add(inAmounts[i].mul(10**18).div(_decimals[i]));
            }
        }
    }
}