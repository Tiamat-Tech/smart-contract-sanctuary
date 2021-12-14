pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./ExchangeWithOrionPool.sol";
import "./utils/orionpool/periphery/interfaces/IOrionPoolV2Router02Ext.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./libs/LibAtomic.sol";

contract ExchangeWithAtomic is ExchangeWithOrionPool {
    mapping(bytes32 => LibAtomic.LockOrder) public atomicSwaps;
    mapping(bytes32 => bytes) public secrets;

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
        require(msg.sender == swap.sender, "E3C");
        _updateBalance(swap.sender, swap.asset, -1*int(swap.amount));
        require(checkPosition(swap.sender), "E1PA");
        require(assetBalances[swap.sender][swap.asset] > 0, "E1A");
        atomicSwaps[swap.secretHash] = swap;

        emit AtomicLocked(swap.sender, swap.secretHash);
    }

    function redeemAtomic(LibAtomic.RedeemOrder calldata order, bytes calldata secret) public nonReentrant {
        LibAtomic.doValidateRedeemOrder(order, secret, secrets);
        _updateBalance(order.sender, order.asset, -1*int(order.amount));
        require(checkPosition(order.sender), "E1PA");

        _updateBalance(order.receiver, order.asset, order.amount);
        secrets[order.secretHash] = secret;

        emit AtomicRedeemed(order.receiver, order.secretHash, secret);
    }

    function claimAtomic(bytes calldata secret, bytes calldata matcherSignature) public nonReentrant {
        LibAtomic.LockOrder storage swap = LibAtomic.doValidateClaimAtomic(
                secret,
                matcherSignature,
                _allowedMatcher,
                atomicSwaps
                );

        swap.used = true;
        _updateBalance(msg.sender, swap.asset, swap.amount);
    }

    function refundAtomic(bytes32 secretHash) public nonReentrant {
        LibAtomic.LockOrder storage swap = LibAtomic.doValidateRefundAtomic(secretHash, atomicSwaps);

        swap.used = true;
        _updateBalance(swap.sender, swap.asset, int(swap.amount));

        emit AtomicRefunded(swap.sender, swap.secretHash);
    }

    /* Error Codes
        E1: Insufficient Balance, flavor A - Atomic, PA - Position Atomic
        E17: Incorrect atomic secret, flavor: U - used, I - not initialized, R - redeemed, E/NE - expired/not expired
   */
}