// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SlidingWindowLedger.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LedgerManager is AccessControl {
    using ECDSA for bytes32;

    bytes32 constant public PRICE_ENGINE_ROLE = keccak256("PRICE_ENGINE_ROLE");

    SlidingWindowLedger private ledger;
    mapping(address => mapping(address => bool)) private allowedPairs;

    constructor (SlidingWindowLedger ledger_, address priceEngine) {
        ledger = ledger_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        if (priceEngine != address(0)) {
            _setupRole(PRICE_ENGINE_ROLE, priceEngine);
        }
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _;
    }

    /**
    * @dev Returns address of the signer.
    */
    function _getMessageSigner(bytes32 messageHash, bytes memory signature) pure internal returns (address) {
        return messageHash
        .toEthSignedMessageHash()
        .recover(signature);
    }

    /**
    * @dev Creates message from ethAddress and phrAddress and returns hash.
    */
    function _createMessageHash(LedgerTypes.OrderInfo memory orderInfo, uint256 endsInSec, uint256 deadline) pure internal returns (bytes32) {
        // TODO maybe it would be possible to pack entire OrderInfo as 1 parameter (abi.encode(orderInfo))
        return keccak256(abi.encodePacked(orderInfo.askAsset, orderInfo.askAmount, orderInfo.offerAsset, orderInfo.offerAmount, orderInfo.owner, endsInSec, deadline));
    }

    /**
    * @dev Checks if particular pair is whitelisted.
    */
    function pairExists(address tokenA, address tokenB) public view returns(bool) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return allowedPairs[token0][token1];
    }

    /**
    * @dev Adds new whitelisted pair.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function addPair(address tokenA, address tokenB) external onlyAdmin {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(allowedPairs[token0][token1] == false, "This pair is already whitelisted");
        allowedPairs[token0][token1] = true;
    }

    /**
    * @dev Removes whitelisted pair.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function removePair(address tokenA, address tokenB) external onlyAdmin {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(allowedPairs[token0][token1], "This pair is not whitelisted");
        allowedPairs[token0][token1] = false;
    }

    /**
    * @dev Adds order into internal order pool and starts other operations.
    *
    * Requirements:
     *
     * - `deadline` must be strictly less than `block.timestamp`.
     * - contract has enough allowance to transfer `msg.sender` token (offerAsset).
     * - pair (offer + ask assets) is whitelisted.
    */
    function addOrder(LedgerTypes.OrderInfo memory orderInfo, uint256 endsInSec, uint256 deadline, bytes memory signature) external returns(uint256) {
        require(deadline >= block.timestamp, "Order approval expired");
        require(IERC20(orderInfo.offerAsset).allowance(msg.sender, address(this)) >= orderInfo.offerAmount, "Allowance for offerAsset is missing");
        require(pairExists(orderInfo.offerAsset, orderInfo.askAsset), "This pair is not whitelisted");
        require(orderInfo.owner == msg.sender, "Sender is not an owner of order");

        bytes32 msgHash = _createMessageHash(orderInfo, endsInSec, deadline);
        _checkRole(PRICE_ENGINE_ROLE, _getMessageSigner(msgHash, signature));

        require(IERC20(orderInfo.offerAsset).transferFrom(msg.sender, address(this), orderInfo.offerAmount), "transferFrom failed");

        return ledger.addOrder(orderInfo, endsInSec);
    }
}