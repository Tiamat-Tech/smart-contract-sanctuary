// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.7.0;
pragma abicoder v2;

import "./TradingAction.sol";
import "./ActionGuards.sol";
import "./nTokenMintAction.sol";
import "./nTokenRedeemAction.sol";
import "../SettleAssetsExternal.sol";
import "../FreeCollateralExternal.sol";
import "../../math/SafeInt256.sol";
import "../../global/StorageLayoutV1.sol";
import "../../internal/balances/BalanceHandler.sol";
import "../../internal/portfolio/PortfolioHandler.sol";
import "../../internal/AccountContextHandler.sol";
import "interfaces/notional/NotionalCallback.sol";

contract BatchAction is StorageLayoutV1, ActionGuards {
    using BalanceHandler for BalanceState;
    using PortfolioHandler for PortfolioState;
    using AccountContextHandler for AccountContext;
    using SafeInt256 for int256;

    /// @notice Executes a batch of balance transfers including minting and redeeming nTokens.
    /// @param account the account for the action
    /// @param actions array of balance actions to take, must be sorted by currency id
    /// @dev emit:CashBalanceChange, emit:nTokenSupplyChange
    /// @dev auth:msg.sender auth:ERC1155
    function batchBalanceAction(address account, BalanceAction[] calldata actions)
        external
        payable
        nonReentrant
    {
        require(account == msg.sender || msg.sender == address(this), "Unauthorized");
        requireValidAccount(account);

        // Return any settle amounts here to reduce the number of storage writes to balances
        AccountContext memory accountContext = _settleAccountIfRequired(account);
        BalanceState memory balanceState;

        for (uint256 i = 0; i < actions.length; i++) {
            BalanceAction calldata action = actions[i];
            // msg.value will only be used when currency id == 1, referencing ETH. The requirement
            // to sort actions by increasing id enforces that msg.value will only be used once.
            if (i > 0) {
                require(action.currencyId > actions[i - 1].currencyId, "Unsorted actions");
            }
            // Loads the currencyId into balance state
            balanceState.loadBalanceState(account, action.currencyId, accountContext);

            _executeDepositAction(
                account,
                balanceState,
                action.actionType,
                action.depositActionAmount
            );

            _calculateWithdrawActionAndFinalize(
                account,
                accountContext,
                balanceState,
                action.withdrawAmountInternalPrecision,
                action.withdrawEntireCashBalance,
                action.redeemToUnderlying
            );
        }

        _finalizeAccountContext(account, accountContext);
    }

    /// @notice Executes a batch of balance transfers and trading actions
    /// @param account the account for the action
    /// @param actions array of balance actions with trades to take, must be sorted by currency id
    /// @dev emit:CashBalanceChange, emit:nTokenSupplyChange, emit:LendBorrowTrade, emit:AddRemoveLiquidity,
    /// @dev emit:SettledCashDebt, emit:nTokenResidualPurchase, emit:ReserveFeeAccrued
    /// @dev auth:msg.sender auth:ERC1155
    function batchBalanceAndTradeAction(address account, BalanceActionWithTrades[] calldata actions)
        external
        payable
        nonReentrant
    {
        require(account == msg.sender || msg.sender == address(this), "Unauthorized");
        requireValidAccount(account);
        AccountContext memory accountContext = _batchBalanceAndTradeAction(account, actions);
        _finalizeAccountContext(account, accountContext);
    }

    /// @notice Executes a batch of balance transfers and trading actions via an authorized callback contract. This
    /// can be used as a "flash loan" facility for special contracts that migrate assets between protocols or perform
    /// other actions on behalf of the user.
    /// Contracts can borrow from Notional and receive a callback prior to an FC check, this can be useful if the contract
    /// needs to perform a trade or repay a debt on a different protocol before depositing collateral. Since Notional's AMM
    /// will never be as capital efficient or gas efficient as other flash loan facilities, this method requires whitelisting
    /// and will mainly be used for contracts that make migrating assets a better user experience.
    /// @param account the account that will take all the actions
    /// @param actions array of balance actions with trades to take, must be sorted by currency id
    /// @param callbackData arbitrary bytes to be passed backed to the caller in the callback
    /// @dev emit:CashBalanceChange, emit:nTokenSupplyChange, emit:LendBorrowTrade, emit:AddRemoveLiquidity,
    /// @dev emit:SettledCashDebt, emit:nTokenResidualPurchase, emit:ReserveFeeAccrued
    /// @dev auth:authorizedCallbackContract
    function batchBalanceAndTradeActionWithCallback(
        address account,
        BalanceActionWithTrades[] calldata actions,
        bytes calldata callbackData
    ) external payable {
        // NOTE: Re-entrancy is allowed for authorized callback functions.
        require(authorizedCallbackContract[msg.sender], "Unauthorized");
        requireValidAccount(account);

        AccountContext memory accountContext = _batchBalanceAndTradeAction(account, actions);
        accountContext.setAccountContext(account);

        // Be sure to set the account context before initiating the callback, all stateful updates
        // have been finalized at this point so we are safe to issue a callback. This callback may
        // re-enter Notional safely to deposit or take other actions.
        NotionalCallback(msg.sender).notionalCallback(msg.sender, account, callbackData);

        if (accountContext.hasDebt != 0x00) {
            // NOTE: this method may update the account context to turn off the hasDebt flag, this
            // is ok because the worst case would be causing an extra free collateral check when it
            // is not required. This check will be entered if the account hasDebt prior to the callback
            // being triggered above, so it will happen regardless of what the callback function does.
            FreeCollateralExternal.checkFreeCollateralAndRevert(account);
        }
    }

    function _batchBalanceAndTradeAction(
        address account,
        BalanceActionWithTrades[] calldata actions
    ) internal returns (AccountContext memory) {
        AccountContext memory accountContext = _settleAccountIfRequired(account);
        BalanceState memory balanceState;
        // NOTE: loading the portfolio state must happen after settle account to get the
        // correct portfolio, it will have changed if the account is settled.
        PortfolioState memory portfolioState = PortfolioHandler.buildPortfolioState(
            account,
            accountContext.assetArrayLength,
            0
        );

        for (uint256 i = 0; i < actions.length; i++) {
            BalanceActionWithTrades calldata action = actions[i];
            // msg.value will only be used when currency id == 1, referencing ETH. The requirement
            // to sort actions by increasing id enforces that msg.value will only be used once.
            if (i > 0) {
                require(action.currencyId > actions[i - 1].currencyId, "Unsorted actions");
            }
            // Loads the currencyId into balance state
            balanceState.loadBalanceState(account, action.currencyId, accountContext);

            // Does not revert on invalid action types here, they also have no effect.
            _executeDepositAction(
                account,
                balanceState,
                action.actionType,
                action.depositActionAmount
            );

            if (action.trades.length > 0) {
                int256 netCash;
                if (accountContext.isBitmapEnabled()) {
                    require(
                        accountContext.bitmapCurrencyId == action.currencyId,
                        "Invalid trades for account"
                    );
                    bool didIncurDebt;
                    (netCash, didIncurDebt) = TradingAction.executeTradesBitmapBatch(
                        account,
                        accountContext.bitmapCurrencyId,
                        accountContext.nextSettleTime,
                        action.trades
                    );
                    if (didIncurDebt) {
                        accountContext.hasDebt = Constants.HAS_ASSET_DEBT | accountContext.hasDebt;
                    }
                } else {
                    // NOTE: we return portfolio state here instead of setting it inside executeTradesArrayBatch
                    // because we want to only write to storage once after all trades are completed
                    (portfolioState, netCash) = TradingAction.executeTradesArrayBatch(
                        account,
                        action.currencyId,
                        portfolioState,
                        action.trades
                    );
                }

                // If the account owes cash after trading, ensure that it has enough
                if (netCash < 0) _checkSufficientCash(balanceState, netCash.neg());
                balanceState.netCashChange = balanceState.netCashChange.add(netCash);
            }

            _calculateWithdrawActionAndFinalize(
                account,
                accountContext,
                balanceState,
                action.withdrawAmountInternalPrecision,
                action.withdrawEntireCashBalance,
                action.redeemToUnderlying
            );
        }

        // Update the portfolio state if bitmap is not enabled. If bitmap is already enabled
        // then all the assets have already been updated in in storage.
        if (!accountContext.isBitmapEnabled()) {
            // NOTE: account context is updated in memory inside this method call.
            accountContext.storeAssetsAndUpdateContext(account, portfolioState, false);
        }

        // NOTE: free collateral and account context will be set outside of this method call.
        return accountContext;
    }

    /// @dev Executes deposits
    function _executeDepositAction(
        address account,
        BalanceState memory balanceState,
        DepositActionType depositType,
        uint256 depositActionAmount_
    ) private {
        int256 depositActionAmount = SafeInt256.toInt(depositActionAmount_);
        int256 assetInternalAmount;
        require(depositActionAmount >= 0);

        if (depositType == DepositActionType.None) {
            return;
        } else if (
            depositType == DepositActionType.DepositAsset ||
            depositType == DepositActionType.DepositAssetAndMintNToken
        ) {
            // NOTE: this deposit will NOT revert on a failed transfer unless there is a
            // transfer fee. The actual transfer will take effect later in balanceState.finalize
            assetInternalAmount = balanceState.depositAssetToken(
                account,
                depositActionAmount,
                false // no force transfer
            );
        } else if (
            depositType == DepositActionType.DepositUnderlying ||
            depositType == DepositActionType.DepositUnderlyingAndMintNToken
        ) {
            // NOTE: this deposit will revert on a failed transfer immediately
            assetInternalAmount = balanceState.depositUnderlyingToken(account, depositActionAmount);
        } else if (depositType == DepositActionType.ConvertCashToNToken) {
            // _executeNTokenAction will check if the account has sufficient cash
            assetInternalAmount = depositActionAmount;
        }

        _executeNTokenAction(
            balanceState,
            depositType,
            depositActionAmount,
            assetInternalAmount
        );
    }

    /// @dev Executes nToken actions
    function _executeNTokenAction(
        BalanceState memory balanceState,
        DepositActionType depositType,
        int256 depositActionAmount,
        int256 assetInternalAmount
    ) private {
        // After deposits have occurred, check if we are minting nTokens
        if (
            depositType == DepositActionType.DepositAssetAndMintNToken ||
            depositType == DepositActionType.DepositUnderlyingAndMintNToken ||
            depositType == DepositActionType.ConvertCashToNToken
        ) {
            // Will revert if trying to mint ntokens and results in a negative cash balance
            _checkSufficientCash(balanceState, assetInternalAmount);
            balanceState.netCashChange = balanceState.netCashChange.sub(assetInternalAmount);

            // Converts a given amount of cash (denominated in internal precision) into nTokens
            int256 tokensMinted = nTokenMintAction.nTokenMint(
                balanceState.currencyId,
                assetInternalAmount
            );

            balanceState.netNTokenSupplyChange = balanceState.netNTokenSupplyChange.add(
                tokensMinted
            );
        } else if (depositType == DepositActionType.RedeemNToken) {
            require(
                // prettier-ignore
                balanceState
                    .storedNTokenBalance
                    .add(balanceState.netNTokenTransfer) // transfers would not occur at this point
                    .add(balanceState.netNTokenSupplyChange) >= depositActionAmount,
                "Insufficient token balance"
            );

            balanceState.netNTokenSupplyChange = balanceState.netNTokenSupplyChange.sub(
                depositActionAmount
            );

            int256 assetCash = nTokenRedeemAction(address(this)).nTokenRedeemViaBatch(
                balanceState.currencyId,
                depositActionAmount
            );

            balanceState.netCashChange = balanceState.netCashChange.add(assetCash);
        }
    }

    /// @dev Calculations any withdraws and finalizes balances
    function _calculateWithdrawActionAndFinalize(
        address account,
        AccountContext memory accountContext,
        BalanceState memory balanceState,
        uint256 withdrawAmountInternalPrecision,
        bool withdrawEntireCashBalance,
        bool redeemToUnderlying
    ) private {
        int256 withdrawAmount = SafeInt256.toInt(withdrawAmountInternalPrecision);
        require(withdrawAmount >= 0); // dev: withdraw action overflow

        // NOTE: if withdrawEntireCashBalance is set it will override the withdrawAmountInternalPrecision input
        if (withdrawEntireCashBalance) {
            // This option is here so that accounts do not end up with dust after lending since we generally
            // cannot calculate exact cash amounts from the liquidity curve.
            withdrawAmount = balanceState.storedCashBalance
                .add(balanceState.netCashChange)
                .add(balanceState.netAssetTransferInternalPrecision);

            // If the account has a negative cash balance then cannot withdraw
            if (withdrawAmount < 0) withdrawAmount = 0;
        }

        // prettier-ignore
        balanceState.netAssetTransferInternalPrecision = balanceState
            .netAssetTransferInternalPrecision
            .sub(withdrawAmount);

        balanceState.finalize(account, accountContext, redeemToUnderlying);
    }

    function _finalizeAccountContext(address account, AccountContext memory accountContext)
        private
    {
        // At this point all balances, market states and portfolio states should be finalized. Just need to check free
        // collateral if required.
        accountContext.setAccountContext(account);
        if (accountContext.hasDebt != 0x00) {
            FreeCollateralExternal.checkFreeCollateralAndRevert(account);
        }
    }

    /// @notice When lending, adding liquidity or minting nTokens the account must have a sufficient cash balance
    /// to do so.
    function _checkSufficientCash(BalanceState memory balanceState, int256 amountInternalPrecision)
        private
        pure
    {
        // The total cash position at this point is: storedCashBalance + netCashChange + netAssetTransferInternalPrecision
        require(
            amountInternalPrecision >= 0 &&
                balanceState.storedCashBalance
                .add(balanceState.netCashChange)
                .add(balanceState.netAssetTransferInternalPrecision) >= amountInternalPrecision,
            "Insufficient cash"
        );
    }

    function _settleAccountIfRequired(address account)
        private
        returns (AccountContext memory)
    {
        AccountContext memory accountContext = AccountContextHandler.getAccountContext(account);
        if (accountContext.mustSettleAssets()) {
            // Returns a new memory reference to account context
            return SettleAssetsExternal.settleAccount(account, accountContext);
        } else {
            return accountContext;
        }
    }
}