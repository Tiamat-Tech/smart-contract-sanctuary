// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SlidingWindowLedger.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Erc20Asset.sol";
import "./NativeAsset.sol";
import "./UniswapExchangeAdapter.sol";

contract LedgerManager is AccessControl, ReentrancyGuard, UniswapExchangeAdapter {
    using ECDSA for bytes32;

    bytes32 constant public PRICE_ENGINE_ROLE = keccak256("PRICE_ENGINE_ROLE");
    bytes32 constant public ORDER_SETTLEMENT_ROLE = keccak256("ORDER_SETTLEMENT_ROLE");

    event OrderFilled(address owner, address askAsset, uint256 askAmount);
    event OrderReverted(address owner, address offerAsset, uint256 offerAmount);

    SlidingWindowLedger public ledger;
    mapping(address => mapping(address => bool)) internal allowedPairs;
    mapping(address => Erc20Asset) public assets;
    NativeAsset public nativeAsset;

    constructor (SlidingWindowLedger ledger_, address priceEngine, IUniswapV2Factory factory_, IUniswapV2Router02 router_)
    UniswapExchangeAdapter(factory_, router_)
    {
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
    * @dev Adds a new supported asset.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function addAsset(Erc20Asset assetStorage) external onlyAdmin {
        address assetAddress = address(assetStorage.assetAddress());
        assets[assetAddress] = assetStorage;
    }

    /**
    * @dev Remove asset from whitelist.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function removeAsset(address asset) external onlyAdmin {
        delete assets[asset];
    }

    /**
    * @dev Sets address of NativeAsset instance.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function setNativeAsset(NativeAsset nativeAssetStorage_) external onlyAdmin {
        nativeAsset = nativeAssetStorage_;
    }

    /**
    * @dev Returns address of the signer.
    */
    function _getMessageSigner(bytes32 messageHash, bytes memory signature) internal pure returns (address) {
        return messageHash
        .toEthSignedMessageHash()
        .recover(signature);
    }

    /**
    * @dev Creates message from ethAddress and phrAddress and returns hash.
    */
    function _createMessageHash(LedgerTypes.OrderInfo memory orderInfo, uint256 endsInSec, uint256 deadline) internal pure returns (bytes32) {
        // TODO maybe it would be possible to pack entire OrderInfo as 1 parameter (abi.encode(orderInfo))
        return keccak256(abi.encodePacked(orderInfo.askAsset, orderInfo.askAmount, orderInfo.offerAsset, orderInfo.offerAmount, orderInfo.owner, endsInSec, deadline));
    }

    /**
    * @dev Checks if particular pair is whitelisted.
    */
    function pairExists(address tokenA, address tokenB) public view returns (bool) {
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
    * @dev Sends funds from user to our erc20 or native asset storage.
    *
    * Requirements:
    *
    * - `asset` is supported by smart contract (can be 0x00 for native).
    */
    function _depositAsset(address asset, uint256 amount) internal {
        if (asset == address(0)) {
            require(address(nativeAsset) != address(0), "Native asset not supported");
            require(msg.value == amount, "Native amount incorrect");
            payable(nativeAsset).transfer(amount);

        } else {
            // solhint-disable-next-line reason-string
            require(IERC20(asset).allowance(msg.sender, address(this)) >= amount, "Allowance for offerAsset is missing");
            require(address(assets[asset]) != address(0), string(abi.encodePacked("Asset ", Strings.toHexString(uint160(asset), 20), " not supported")));

            require(IERC20(asset).transferFrom(msg.sender, address(assets[asset]), amount), "transferFrom failed");
        }
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
    function addOrder(LedgerTypes.OrderInfo memory orderInfo, uint256 endsInSec, uint256 deadline, bytes memory signature) external payable returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "Order approval expired");
        require(pairExists(orderInfo.offerAsset, orderInfo.askAsset), "This pair is not whitelisted");
        require(orderInfo.owner == msg.sender, "Sender is not an owner of order");

        bytes32 msgHash = _createMessageHash(orderInfo, endsInSec, deadline);
        _checkRole(PRICE_ENGINE_ROLE, _getMessageSigner(msgHash, signature));

        _depositAsset(orderInfo.offerAsset, orderInfo.offerAmount);

        return ledger.addOrder(orderInfo, endsInSec);
    }

    struct SettlementInfo {
        uint256 orderId;
        bool fillOrder;
    }

    struct FundsInfo {
        address from;
        uint256 fromAmount;
        address to;
        uint256 toAmount;
    }

    /**
    * @dev Withdraw funds from asset storage to `recipient`
    *
    * Requirements:
    *
    * - `asset` is supported by smart contract (can be 0x00 for native).
    */
    function _withdrawAsset(address recipient, address asset, uint256 amount) internal {
        if (asset == address(0)) {
            // native asset
            require(address(nativeAsset) != address(0), "Native asset not supported");
            nativeAsset.transfer(payable(recipient), amount);
        } else {
            // erc20 asset
            require(address(assets[asset]) != address(0), string(abi.encodePacked("Asset ", Strings.toHexString(uint160(asset), 20), " not supported")));
            assets[asset].transfer(recipient, amount);
        }
    }

    /**
    * @dev See 'swapAssets' docs
    */
    function _swapAssets(FundsInfo[] calldata fundsInfo) internal {
        for (uint256 i = 0; i < fundsInfo.length; i++) {
            FundsInfo memory fundInfo = fundsInfo[i];
            if (fundInfo.from == address(0)) { // from native to token
                require(fundInfo.to != address(0), "Cannot exchange native for native");
                exchangeNativeForToken(nativeAsset, fundInfo.fromAmount, assets[fundInfo.to], fundInfo.toAmount);
            } else if (fundInfo.to == address(0)) { // from token to native
                exchangeTokenForNative(assets[fundInfo.from], fundInfo.fromAmount, nativeAsset, fundInfo.toAmount);
            } else { // tokens
                exchangeTokens(assets[fundInfo.from], fundInfo.fromAmount, assets[fundInfo.to], fundInfo.toAmount);
            }
        }
    }

    /**
    * @dev Function executed by dex cron, it prepares assets for future orders
    *
    * Requirements:
    *
    * - `msg.sender` must have ORDER_SETTLEMENT_ROLE role.
    * - fundsInfo is correctly calculated and given to manager.
    */
    function swapAssets(FundsInfo[] calldata fundsInfo) external onlyRole(ORDER_SETTLEMENT_ROLE) nonReentrant {
        return _swapAssets(fundsInfo);
    }

    /**
    * @dev Function executed by dex cron, it fulfills orders given in the `settleInfo` list
    *
    * Requirements:
    *
    * - `msg.sender` must have ORDER_SETTLEMENT_ROLE role.
    * - fundsInfo is correctly calculated and given to manager.
    * - all orders from `settleInfo` list exists.
    */
    function settleOrders(SettlementInfo[] calldata settleInfo, FundsInfo[] calldata fundsInfo) external onlyRole(ORDER_SETTLEMENT_ROLE) nonReentrant {
        _swapAssets(fundsInfo);

        for (uint256 i = 0; i < settleInfo.length; i++) {
            SettlementInfo memory info = settleInfo[i];
            LedgerTypes.OrderInfo memory orderInfo = ledger.getOrder(info.orderId);
            require(ledger.removeOrder(info.orderId), "Order didn't exists");

            if (info.fillOrder) {
                _withdrawAsset(orderInfo.owner, orderInfo.askAsset, orderInfo.askAmount);
                emit OrderFilled(orderInfo.owner, orderInfo.askAsset, orderInfo.askAmount);
            } else {
                _withdrawAsset(orderInfo.owner, orderInfo.offerAsset, orderInfo.offerAmount);
                emit OrderReverted(orderInfo.owner, orderInfo.offerAsset, orderInfo.offerAmount);
            }
        }
    }
}