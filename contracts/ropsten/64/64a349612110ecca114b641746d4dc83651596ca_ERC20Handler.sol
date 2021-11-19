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
        @dev Depending if the corresponding {tokenAddress} for the parsed {resourceID} is
        marked true in {_burnList}, deposited tokens will be burned, if not, they will be locked.
        @return an empty data.
     */
    function deposit(
        bytes32 resourceID,
        address depositor,
        uint amount
    ) external override onlyBridge returns (bytes memory) {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(_contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");

        burnERC20(tokenAddress, depositor, amount);
    }

    /**
        @notice Proposal execution should be initiated when a proposal is finalized in the Bridge contract.
        by a relayer on the deposit's destination chain.
        @param amount Amount Of the Proposal
     */
    function executeProposal(bytes32 resourceID, uint amount, address recipientAddress) external override onlyBridge {
        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(_contractWhitelist[tokenAddress], "provided tokenAddress is not whitelisted");

        mintERC20(tokenAddress, recipientAddress, amount);
    }

    /**
        @notice Used to manually release ERC20 tokens from ERC20Safe.
     */
    function withdraw(address tokenAddress, address recipient, uint amount) external override onlyBridge {
        releaseERC20(tokenAddress, recipient, amount);
    }
}