pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./LibValidator.sol";

library LibAtomic {
    using ECDSA for bytes32;

    struct LockOrder {
        address sender;
        address asset;
        uint64 amount;
        uint64 expiration;
        bytes32 secretHash;
        bool used;
    }

    struct ClaimOrder {
        address receiver;
        bytes32 secretHash;
    }

    struct RedeemOrder {
        address sender;
        address receiver;
        address asset;
        uint64 amount;
        uint64 expiration;
        bytes32 secretHash;
        bytes signature;
    }

    function doValidateRedeemOrder(
                RedeemOrder calldata order,
                bytes calldata secret,
                mapping(bytes32 => bytes) storage secrets) public view {
        require(msg.sender == order.receiver, "E3C");
        require(secrets[order.secretHash].length == 0, "E17R");
        validatelAtomic(order, block.timestamp);
        require(order.secretHash == keccak256(secret), "E17");
    }

    function doValidateClaimAtomic(
            bytes calldata secret,
            bytes calldata matcherSignature,
            address allowedMatcher,
            mapping(bytes32 => LockOrder) storage atomicSwaps)
                public view returns(LockOrder storage swap) {
        bytes32 secretHash = keccak256(secret);
        require(getEthSignedClaimOrderHash(ClaimOrder(msg.sender, secretHash)).recover(matcherSignature) == allowedMatcher, "E2");

        swap = atomicSwaps[secretHash];
        require(swap.sender != address(0x0), "E17I");
        require(swap.expiration/1000 >= block.timestamp, "E17E");
        require(!swap.used, "E17U");
    }

    function doValidateRefundAtomic(
            bytes32 secretHash,
            mapping(bytes32 => LockOrder) storage atomicSwaps)
                public view returns(LockOrder storage swap) {
        swap = atomicSwaps[secretHash];
        require(swap.expiration/1000 < block.timestamp, "E17NE");
        require(!swap.used, "E17U");
    }

    function getEthSignedAtomicOrderHash(RedeemOrder calldata _order) internal pure returns (bytes32) {
        return
        keccak256(
            abi.encodePacked(
                "atomicOrder",
                _order.sender,
                _order.receiver,
                _order.asset,
                _order.amount,
                _order.expiration,
                _order.secretHash
            )
        ).toEthSignedMessageHash();
    }

    function getEthSignedClaimOrderHash(ClaimOrder memory _order) internal pure returns (bytes32) {
        return
        keccak256(
            abi.encodePacked(
                "claimOrder",
                _order.receiver,
                _order.secretHash
            )
        ).toEthSignedMessageHash();
    }

    function validatelAtomic(RedeemOrder calldata order, uint currentTime) internal pure returns (bool) {
        require(getEthSignedAtomicOrderHash(order).recover(order.signature) == order.sender, "E2");
        // Check Expiration Time. Convert to seconds first
        require(order.expiration/1000 >= currentTime, "E4A");
        return true;
    }
}