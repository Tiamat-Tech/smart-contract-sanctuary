// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.6.12;

import "../interfaces/IDepositExecute.sol";
import "./HandlerHelpers.sol";
import "../ERC20Safe.sol";

/**
    @title Handles ERC20 deposits and deposit executions.
    @author ChainSafe Systems.
    @notice This contract is intended to be used with the Bridge contract.
 */
contract ERC20Handler is IDepositExecute, HandlerHelpers, ERC20Safe {
    /**
        @param bridgeAddress Contract address of previously deployed Bridge.
     */
    constructor(
        address          bridgeAddress
    ) public HandlerHelpers(bridgeAddress) {
    }

    /**
        @notice A deposit is initiatied by making a deposit in the Bridge contract.
        @param resourceID ResourceID used to find address of token to be used for deposit.
        @param depositor Address of account making the deposit in the Bridge contract.
        @param amount Amount of the deposit.
     */
    function deposit(
        bytes32 resourceID,
        address depositor,
        uint amount
    ) external override onlyBridge {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(_contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");

        if (_burnList[tokenAddress]) {
            burnERC20(tokenAddress, depositor, amount);
        } else {
            lockERC20(tokenAddress, depositor, address(this), amount);
        }
    }

    /**
        @notice Proposal execution should be initiated when a proposal is finalized in the Bridge contract.
        by a relayer on the deposit's destination chain.
        @param amount Amount Of the proposal.
        @param recipient Address Of the proposal.
     */
    function executeProposal(bytes32 resourceID, uint amount, address recipient) external override onlyBridge {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(_contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");

        if (_burnList[tokenAddress]) {
            mintERC20(tokenAddress, address(recipient), amount);
        } else {
            releaseERC20(tokenAddress, address(recipient), amount);
        }
    }

    /**
        @notice Used to manually release ERC20 tokens from ERC20Safe.
        @param token Address of the token for this withdrawal.
        @param recipient Address of the recipient for this withdrawal.
        @param amount Amount for this withdrawal.
     */
    function withdraw(address token, address recipient, uint amount) external override onlyBridge {
        releaseERC20(token, recipient, amount);
    }
}