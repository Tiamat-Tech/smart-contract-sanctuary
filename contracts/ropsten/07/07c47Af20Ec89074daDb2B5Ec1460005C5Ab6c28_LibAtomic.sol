pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./LibValidator.sol";
import "./LibExchange.sol";

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

    struct RedeemInfo {
        address receiver;
        bytes secret;
    }

    function doLockAtomic(LockOrder memory swap,
        mapping(bytes32 => LockOrder) storage atomicSwaps,
        mapping(address => mapping(address => int192)) storage assetBalances,
        mapping(address => MarginalFunctionality.Liability[]) storage liabilities
    ) public {
        require(msg.sender == swap.sender, "E3C");
        LibExchange._updateBalance(swap.sender, swap.asset, -1*int(swap.amount), assetBalances, liabilities);
        require(assetBalances[swap.sender][swap.asset] > 0, "E1A");
        atomicSwaps[swap.secretHash] = swap;
    }

    function doRedeemAtomic(
        LibAtomic.RedeemOrder calldata order,
        bytes calldata secret,
        mapping(bytes32 => RedeemInfo) storage secrets,
        mapping(address => mapping(address => int192)) storage assetBalances,
        mapping(address => MarginalFunctionality.Liability[]) storage liabilities
    ) public {
        require(msg.sender == order.receiver, "E3C");
        require(secrets[order.secretHash].receiver == address(0x0), "E17R");
        require(getEthSignedAtomicOrderHash(order).recover(order.signature) == order.sender, "E2");
        require(order.expiration/1000 >= block.timestamp, "E4A");
        require(order.secretHash == keccak256(secret), "E17");

        LibExchange._updateBalance(order.sender, order.asset, -1*int(order.amount), assetBalances, liabilities);

        LibExchange._updateBalance(order.receiver, order.asset, order.amount, assetBalances, liabilities);
        secrets[order.secretHash] = RedeemInfo(order.receiver, secret);
    }

    function doClaimAtomic(
        address receiver,
        bytes calldata secret,
        bytes calldata matcherSignature,
        address allowedMatcher,
        mapping(bytes32 => LockOrder) storage atomicSwaps,
        mapping(address => mapping(address => int192)) storage assetBalances,
        mapping(address => MarginalFunctionality.Liability[]) storage liabilities
    ) public {
        bytes32 secretHash = keccak256(secret);
        require(getEthSignedClaimOrderHash(ClaimOrder(receiver, secretHash)).recover(matcherSignature) == allowedMatcher, "E2");

        LockOrder storage swap = atomicSwaps[secretHash];
        require(swap.sender != address(0x0), "E17I");
        require(swap.expiration/1000 >= block.timestamp, "E17E");
        require(!swap.used, "E17U");

        swap.used = true;
        LibExchange._updateBalance(receiver, swap.asset, swap.amount, assetBalances, liabilities);
    }

    function doRefundAtomic(
        bytes32 secretHash,
        mapping(bytes32 => LockOrder) storage atomicSwaps,
        mapping(address => mapping(address => int192)) storage assetBalances,
        mapping(address => MarginalFunctionality.Liability[]) storage liabilities
    ) public returns(LockOrder storage swap) {
        swap = atomicSwaps[secretHash];
        require(swap.expiration/1000 < block.timestamp, "E17NE");
        require(!swap.used, "E17U");

        swap.used = true;
        LibExchange._updateBalance(swap.sender, swap.asset, int(swap.amount), assetBalances, liabilities);
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
}