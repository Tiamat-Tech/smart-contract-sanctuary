// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.7.6;

import "./TransferHelper.sol";

// @title Hash timelock contract for Ether
contract EtherSwap {
    // State variables

    /// @dev Version of the contract used for compatibility checks
    uint8 constant public version = 2;

    /// @dev Mapping between value hashes of swaps and whether they have Ether locked in the contract
    mapping (bytes32 => bool) public swaps;

    // Events

    event Lockup(
        bytes32 indexed preimageHash,
        uint amount,
        address claimAddress,
        address indexed refundAddress,
        uint timelock
    );

    event Claim(bytes32 indexed preimageHash, bytes32 preimage);
    event Refund(bytes32 indexed preimageHash);

    // Functions

    // External functions

    /// Locks Ether for a swap in the contract
    /// @notice The amount locked is the Ether sent in the transaction and the refund address is the sender of the transaction
    /// @param preimageHash Preimage hash of the swap
    /// @param claimAddress Address that can claim the locked Ether
    /// @param timelock Block height after which the locked Ether can be refunded
    function lock(
        bytes32 preimageHash,
        address claimAddress,
        uint timelock
    ) external payable {
        lockEther(preimageHash, msg.value, claimAddress, timelock);
    }

    /// Locks Ether for a swap in the contract and forwards a specified amount of Ether to the claim address
    /// @notice The amount locked is the Ether sent in the transaction minus the prepay amount and the refund address is the sender of the transaction
    /// @dev Make sure to set a reasonable gas limit for calling this function, else a malicious contract at the claim address could drain your Ether
    /// @param preimageHash Preimage hash of the swap
    /// @param claimAddress Address that can claim the locked Ether
    /// @param timelock Block height after which the locked Ether can be refunded
    /// @param prepayAmount Amount that should be forwarded to the claim address
    function lockPrepayMinerfee(
        bytes32 preimageHash,
        address payable claimAddress,
        uint timelock,
        uint prepayAmount
    ) external payable {
        // Revert on underflow in next statement
        require(msg.value > prepayAmount, "EtherSwap: sent amount must be greater than the prepay amount");

        // Lock the amount of Ether sent minus the prepay amount in the contract
        lockEther(preimageHash, msg.value - prepayAmount, claimAddress, timelock);

        // Forward the prepay amount to the claim address
        TransferHelper.transferEther(claimAddress, prepayAmount);
    }

    /// Claims Ether locked in the contract
    /// @dev To query the arguments of this function, get the "Lockup" event logs for the SHA256 hash of the preimage
    /// @param preimage Preimage of the swap
    /// @param amount Amount locked in the contract for the swap in WEI
    /// @param refundAddress Address that locked the Ether in the contract
    /// @param timelock Block height after which the locked Ether can be refunded
    function claim(
        bytes32 preimage,
        uint amount,
        address refundAddress,
        uint timelock
    ) external {
        // If the preimage is wrong, so will be its hash which will result in a wrong value hash and no swap being found
        bytes32 preimageHash = sha256(abi.encodePacked(preimage));

        // Passing "msg.sender" as "claimAddress" to "hashValues" ensures that only the destined address can claim
        // All other addresses would produce a different hash for which no swap can be found in the "swaps" mapping
        bytes32 hash = hashValues(
            preimageHash,
            amount,
            msg.sender,
            refundAddress,
            timelock
        );

        // Make sure that the swap to be claimed has Ether locked
        checkSwapIsLocked(hash);
        // Delete the swap from the mapping to ensure that it cannot be claimed or refunded anymore
        // This *HAS* to be done before actually sending the Ether to avoid reentrancy
        delete swaps[hash];

        // Emit the claim event
        emit Claim(preimageHash, preimage);

        // Transfer the Ether to the claim address
        TransferHelper.transferEther(payable(msg.sender), amount);
    }

    /// Refunds Ether locked in the contract
    /// @dev To query the arguments of this function, get the "Lockup" event logs for your refund address and the preimage hash if you have it
    /// @dev For further explanations and reasoning behind the statements in this function, check the "claim" function
    /// @param preimageHash Preimage hash of the swap
    /// @param amount Amount locked in the contract for the swap in WEI
    /// @param claimAddress Address that that was destined to claim the funds
    /// @param timelock Block height after which the locked Ether can be refunded
    function refund(
        bytes32 preimageHash,
        uint amount,
        address claimAddress,
        uint timelock
    ) external {
        // Make sure the timelock has expired already
        // If the timelock is wrong, so will be the value hash of the swap which results in no swap being found
        require(timelock <= block.number, "EtherSwap: swap has not timed out yet");

        bytes32 hash = hashValues(
            preimageHash,
            amount,
            claimAddress,
            msg.sender,
            timelock
        );

        checkSwapIsLocked(hash);
        delete swaps[hash];

        emit Refund(preimageHash);

        TransferHelper.transferEther(payable(msg.sender), amount);
    }

    // Public functions

    /// Hashes all the values of a swap with Keccak256
    /// @param preimageHash Preimage hash of the swap
    /// @param amount Amount the swap has locked in WEI
    /// @param claimAddress Address that can claim the locked Ether
    /// @param refundAddress Address that locked the Ether and can refund them
    /// @param timelock Block height after which the locked Ether can be refunded
    /// @return Value hash of the swap
    function hashValues(
        bytes32 preimageHash,
        uint amount,
        address claimAddress,
        address refundAddress,
        uint timelock
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            preimageHash,
            amount,
            claimAddress,
            refundAddress,
            timelock
        ));
    }

    // Private functions

    /// Locks Ether in the contract
    /// @notice The refund address is the sender of the transaction
    /// @param preimageHash Preimage hash of the swap
    /// @param amount Amount to be locked in the contract
    /// @param claimAddress Address that can claim the locked Ether
    /// @param timelock Block height after which the locked Ether can be refunded
    function lockEther(bytes32 preimageHash, uint amount, address claimAddress, uint timelock) private {
        // Locking zero WEI in the contract is pointless
        require(amount > 0, "EtherSwap: locked amount must not be zero");

        // Hash the values of the swap
        bytes32 hash = hashValues(
            preimageHash,
            amount,
            claimAddress,
            msg.sender,
            timelock
        );

        // Make sure no swap with this value hash exists yet
        require(swaps[hash] == false, "EtherSwap: swap exists already");

        // Save to the state that funds were locked for this swap
        swaps[hash] = true;

        // Emit the "Lockup" event
        emit Lockup(preimageHash, amount, claimAddress, msg.sender, timelock);
    }

    /// Checks whether a swap has Ether locked in the contract
    /// @dev This function reverts if the swap has no Ether locked in the contract
    /// @param hash Value hash of the swap
    function checkSwapIsLocked(bytes32 hash) private view {
        require(swaps[hash] == true, "EtherSwap: swap has no Ether locked in the contract");
    }
}