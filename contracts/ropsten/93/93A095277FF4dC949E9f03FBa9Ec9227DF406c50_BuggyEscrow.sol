pragma solidity 0.8.11;

// Can use console.log() for debugging.
import "hardhat/console.sol";

import { ECDSA } from "./openzeppelin/ECDSA.sol";
import { IERC20 } from "./openzeppelin/IERC20.sol";
import { Rescuable } from "./Rescuable.sol";
import { SecretKeyOwnable } from "./SecretKeyOwnable.sol";

/**
 * @title BuggyEscrow
 * @author Royal
 *
 * @notice A buggy contract that attempts to implement an escrow use case.
 *
 *  THIS CODE CONTAINS VULNERABILITIES. DO NOT USE THIS CODE IN PRODUCTION.
 *
 * ---------------------------------------------------------------------------
 *
 *  Escrow contract that supports atomic swaps of any two ERC-20 tokens between two parties.
 *
 *  This contract inherits from Rescuable.sol and SecretKeyOwnable.sol. Within BuggyEscrow.sol
 *  we expose 5 external state-changing functions for interacting with swaps:
 *    - initiateSwap
 *    - initiateSwapWithSig
 *    - completeSwap
 *    - completeSwapBySig
 *    - cancelSwap
 *
 *  CONTRACT LIFECYCLE:
 *
 *  1. Initiate a swap:
 *
 *    A swap is initiated by specifying the following:
 *      - The address of each party to the swap
 *      - The addresses of the tokens to be paid by each party
 *      - The amount of token to be paid by each party
 *
 *    Upon initiating a swap, party A's tokens are transfered to this contract and held in escrow.
 *
 *  2. After initiating a swap, one of two things can happen:
 *
 *    - Canceled by party A: Funds are returned to party A from escrow.
 *
 *    - Completed by party B: Party B transfers funds to party A according to the agreed terms.
 *      Funds are released from escrow to party B.
 */
contract BuggyEscrow is
    Rescuable
{
    // ==================== Structs ==================== //

    /// @notice The info for one side of a swap.
    struct SwapInfo {
        address party;
        IERC20 token;
        uint256 tokenAmount;
    }

    // ==================== Storage ==================== //

    /// @dev Mapping from keccak256(partyA, tokenA, tokenAmountA) => (partyB, tokenB, tokenAmount)
    mapping(bytes32 => SwapInfo) internal _PENDING_SWAPS_;

    /// @dev Mapping from (token) => (total escrowed amount across all pending swaps)
    mapping(IERC20 => uint256) internal _TOTAL_ESCROWED_AMOUNT_;

    // ==================== Constructor ==================== //

    constructor(
        string memory secretKey,
        bytes32 secretKeyHash
    )
        SecretKeyOwnable(secretKeyHash)
    {
        require(
            _isSecretKey(secretKey),
            "sanity check failed"
        );
    }

    // ==================== External Functions ==================== //

    /**
     * @notice Initiate a swap.
     *
     *  Party A is authorized by checking msg.sender.
     *
     *  Will revert if party A does not have an ERC-20 allowance set on this contract for token A.
     */
    function initiateSwap(
        SwapInfo calldata sideA,
        SwapInfo calldata sideB
    )
        external
    {
        require(
            msg.sender == sideA.party,
            "sender must be party A"
        );
        _initiateSwap(sideA, sideB);
    }

    /**
     * @notice Initiate a swap.
     *
     *  Party A is authorized by checking the provided signature.
     *
     *  Will revert if party A does not have an ERC-20 allowance set on this contract for token A.
     */
    function initiateSwapWithSig(
        SwapInfo calldata sideA,
        SwapInfo calldata sideB,
        bytes calldata partyASignature
    )
        external
    {
        bytes memory message = abi.encode(
            sideA.token,
            sideA.tokenAmount,
            sideB.token,
            sideB.tokenAmount
        );
        _validateSignature(message, partyASignature, sideA.party);
        _initiateSwap(sideA, sideB);
    }

    /**
     * @notice Complete a swap.
     *
     *  Party B is authorized by checking msg.sender.
     *
     *  Will revert if party B does not have an ERC-20 allowance set on this contract for token B.
     */
    function completeSwap(
        SwapInfo calldata sideA
    )
        external
    {
        SwapInfo memory sideB = getPendingSwap(sideA);

        require(
            msg.sender == sideB.party,
            "sender must be party B"
        );

        _completeSwap(sideA, sideB);
    }

    /**
     * @notice Complete a swap.
     *
     *  Party B is authorized by checking the provided signature.
     *
     *  Will revert if party B does not have an ERC-20 allowance set on this contract for token B.
     */
    function completeSwapBySig(
        SwapInfo calldata sideA,
        bytes calldata partyBSignature
    )
        external
    {
        SwapInfo memory sideB = getPendingSwap(sideA);

        bytes memory message = abi.encode(
            sideA.token,
            sideA.tokenAmount,
            sideB.token,
            sideB.tokenAmount
        );
        _validateSignature(message, partyBSignature, sideB.party);

        _completeSwap(sideA, sideB);
    }

    /**
     * @notice Cancel a swap.
     *
     *  Party A is authorized by checking msg.sender.
     */
    function cancelSwap(
        SwapInfo calldata sideA
    )
        external
    {
        require(
            msg.sender == sideA.party,
            "sender must be party A"
        );
        _cancelSwap(sideA);
    }

    // ==================== Public Functions ==================== //

    /**
     * @notice Get info about a pending swap.
     */
    function getPendingSwap(
        SwapInfo memory sideA
    )
        public
        view
        returns (SwapInfo memory)
    {
        return _PENDING_SWAPS_[keccak256(abi.encode(sideA))];
    }

    // ==================== Internal Functions ==================== //

    /**
     * @notice Set a pending swap.
     */
    function _setPendingSwap(
        SwapInfo memory sideA,
        SwapInfo memory sideB
    )
        internal
    {
        _PENDING_SWAPS_[keccak256(abi.encode(sideA))] = sideB;
    }

    /**
     * @notice Delete a pending swap.
     */
    function _deletePendingSwap(
        SwapInfo memory sideA
    )
        internal
    {
        delete _PENDING_SWAPS_[keccak256(abi.encode(sideA))];
    }

    function _initiateSwap(
        SwapInfo memory sideA,
        SwapInfo memory sideB
    )
        internal
    {
        require(
            sideB.party != address(0),
            "party B cannot be zero"
        );

        // Store information about the pending swap.
        _setPendingSwap(sideA, sideB);

        // Escrow an amount of token A to be transfered to party B upon completion of the swap.
        sideA.token.transferFrom(sideA.party, address(this), sideA.tokenAmount);
    }

    function _completeSwap(
        SwapInfo memory sideA,
        SwapInfo memory sideB
    )
        internal
    {
        // Delete the pending swap.
        _deletePendingSwap(sideA);

        // Transfer from B -> A.
        sideB.token.transferFrom(sideB.party, sideA.party, sideB.tokenAmount);

        // Complete the escrowed transfer from A -> B.
        sideA.token.transfer(sideB.party, sideA.tokenAmount);
    }

    function _cancelSwap(
        SwapInfo memory sideA
    )
        internal
    {
        SwapInfo memory sideB = getPendingSwap(sideA);

        require(
            sideB.party != address(0),
            "swap is not pending"
        );

        // Delete the pending swap.
        _deletePendingSwap(sideA);

        // Return funds from escrow to party A.
        sideA.token.transferFrom(address(this), sideA.party, sideA.tokenAmount);
    }

    function _validateSignature(
        bytes memory message,
        bytes memory signature,
        address expectedSigner
    )
        internal
        pure
    {
        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(message));
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(
            recoveredSigner == expectedSigner,
            "invalid signer"
        );
    }

    function _getExcessEthAmount()
        internal
        view
        override
        returns (uint256)
    {
        // Any ETH balance is excess since the contract does not expect to hold any ETH.
        return address(this).balance;
    }
}