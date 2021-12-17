pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./ExchangeWithOrionPool.sol";
import "./utils/orionpool/periphery/interfaces/IOrionPoolV2Router02Ext.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./libs/LibAtomic.sol";

contract ExchangeWithAtomic is ExchangeWithOrionPool {
    mapping(bytes32 => LibAtomic.LockOrder) public atomicSwaps;
    mapping(bytes32 => LibAtomic.RedeemInfo) public secrets;

    event AtomicLocked(
        address sender,
        bytes32 secretHash
    );

    event AtomicRedeemed(
        address receiver,
        bytes32 secretHash,
        bytes secret
    );

    event AtomicRefunded(
        address receiver,
        bytes32 secretHash
    );

    function lockAtomic(LibAtomic.LockOrder memory swap) public nonReentrant {
        LibAtomic.doLockAtomic(swap, atomicSwaps, assetBalances, liabilities);

        require(checkPosition(swap.sender), "E1PA");

        emit AtomicLocked(swap.sender, swap.secretHash);
    }

    function redeemAtomic(LibAtomic.RedeemOrder calldata order, bytes calldata secret) public nonReentrant {
        LibAtomic.doRedeemAtomic(order, secret, secrets, assetBalances, liabilities);
        require(checkPosition(order.sender), "E1PA");

        emit AtomicRedeemed(order.receiver, order.secretHash, secret);
    }

    function claimAtomic(address receiver, bytes calldata secret, bytes calldata matcherSignature) public nonReentrant {
        LibAtomic.doClaimAtomic(
                receiver,
                secret,
                matcherSignature,
                _allowedMatcher,
                atomicSwaps,
                assetBalances,
                liabilities
        );
    }

    function refundAtomic(bytes32 secretHash) public nonReentrant {
        LibAtomic.LockOrder storage swap = LibAtomic.doRefundAtomic(secretHash, atomicSwaps, assetBalances, liabilities);

        emit AtomicRefunded(swap.sender, swap.secretHash);
    }

    /* Error Codes
        E1: Insufficient Balance, flavor A - Atomic, PA - Position Atomic
        E17: Incorrect atomic secret, flavor: U - used, I - not initialized, R - redeemed, E/NE - expired/not expired
   */
}