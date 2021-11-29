pragma solidity ^0.8.0;

import "./Base.sol";

import "./Vault.sol";
import "./Storage.sol";

import "./handlers/UniswapV2.sol";
import "./handlers/BancorNetwork.sol";
import "./handlers/Curve.sol";
import "./handlers/InternalSwap.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

enum DEX {
    UNISWAPV2,
    SUSHISWAPV2,
    BANCOR,
    ZEROX,
    CURVE,
    INTERNAL
}

/**
 * @title A main DeFire ecosystem contract.
 * @notice This is a central point for placing, storing and executing orders.
 */
contract Main is
    Base,
    UniswapV2Handler,
    BancorNetworkHandler,
    CurveHandler,
    InternalSwapHandler
{
    using SafeERC20 for IERC20;

    event OrderCreated(address indexed creator, bytes32 hash);
    event OrderFill(
        bytes32 indexed hash,
        uint256 amountBase,
        uint256 amountQuote
    );
    event OrderCancelled(bytes32 indexed hash);
    event OrderExpired(bytes32 indexed hash);
    event OrderChanged(bytes32 indexed hash);

    address internal storage_;

    mapping(address => bool) internal executors;

    bool public initialized = false; // used for initializer, to allow calling it only once

    /**
     * @dev Initializes the Main contract, since constructor cannot be used due to nature of EIP1967 standard.
     * @param _storage An address of storage contract.
     * @param _vault And address of vault contract.
     */
    function initialize(
        address _storage,
        address payable _vault,
        address _contractRegistry,
        address _initialExecutor,
        address _weth
    ) external {
        require(initialized == false, "Contract has already been initialized.");

        storage_ = _storage;
        vault = _vault;
        weth = _weth;

        StorageInstance = Storage(storage_);
        VaultInstance = Vault(vault);

        contractRegistry = IContractRegistry(_contractRegistry);

        executors[_initialExecutor] = true;

        initialized = true;
    }

    // this modifier checks if hash argument identifies existing order
    // this modifier will revert transaction if hash does not belong to existing order
    modifier orderExists(bytes32 hash) {
        require(
            _getVolume(hash) > 0,
            "Order does not exist or invalid order hash."
        ); // since baseToken in order cannot be zero address, we are comparing it to such

        _;
    }

    // this modifier checks if hash argument is one of the market order
    // this modifier will revert transaction if order is not market order
    modifier onlyMarketOrder(bytes32 hash) {
        require(
            _getOrderType(hash) == uint256(OrderType.MARKET_ORDER),
            "Invalid order type."
        );

        _;
    }

    // this modifier checks if hash argument belongs to limit order
    // this modifier will revert transaction if order type is not limit order
    modifier onlyLimitOrder(bytes32 hash) {
        require(
            _getOrderType(hash) == uint256(OrderType.LIMIT_ORDER),
            "Invalid order type."
        );

        _;
    }

    // this modifier checks if msg.sender has permission to execute certain order
    // only order creator or executor addresses are approved
    modifier onlyExecutorAndCreator(bytes32 hash) {
        require(
            (_getCreator(hash) == msg.sender || executors[msg.sender]),
            "Only executor and order creator can execute this order."
        );

        _;
    }

    modifier onlyOngoingOrders(bytes32 hash) {
        require(
            _getOrderStatus(hash) == uint256(OrderStatus.ONGOING),
            "Order is finished, this operation cannot be completed."
        );

        _;
    }

    modifier notExpired(bytes32 hash) {
        uint256 expTime = _getExpirationTime(hash);

        require(
            expTime == 0 || expTime >= block.timestamp,
            "Order is expired, it cannot be filled."
        );

        _;
    }

    // ADMINISTRATION LOGIC - START

    /**
     * @dev Returns true if passed address is executor, else returns false.
     * @param _addr Address to be tested.
     * @return Returns boolean type.
     */
    function isExecutor(address _addr) external view returns (bool) {
        return executors[_addr];
    }

    /**
     * @dev Sets another address as an executor.
     * @param _addr Address to be set as an executor.
     *
     * This function can only be called by an approved executor.
     */
    function approveExecutor(address _addr) external {
        require(
            executors[msg.sender],
            "Only approved executors can call this function."
        );

        executors[_addr] = true;
    }

    /**
     * @dev Revokes another executor address.
     * @param _addr Address to be revoked an executor permission.
     *
     * This function can only be called by an approved executor.
     */
    function revokeExecutor(address _addr) external {
        require(
            executors[msg.sender],
            "Only approved executors can call this function."
        );

        executors[_addr] = false;
    }

    // ADMINISTRATION LOGIC - END

    // ORDER CREATION, MANAGMENT AND EXECUTION LOGIC - START

    /**
     * @notice Creates a new market order.
     * @param baseToken Token to be sold.
     * @param quoteToken Token to be bought.
     * @param volume Amount of base token to be sold.
     * @param minimumReturns Minimum amount of quoteToken to be received.
     *
     * Function will fail if volume and minimum returns are less than or equal to zero.
     */
    function createMarketOrder(
        address baseToken,
        address quoteToken,
        uint256 volume,
        uint256 minimumReturns
    ) external {
        require(volume > 0, "Invalid volume provided.");
        require(minimumReturns > 0, "Invalid minimum returns provided.");

        bytes32 hash = keccak256(
            abi.encodePacked(
                baseToken,
                quoteToken,
                volume,
                msg.sender,
                block.timestamp,
                uint256(OrderType.MARKET_ORDER)
            )
        );

        _setUintForOrder(hash, "orderType", uint256(OrderType.MARKET_ORDER));
        _setAddressForOrder(hash, "baseToken", baseToken);
        _setAddressForOrder(hash, "quoteToken", quoteToken);
        _setUintForOrder(hash, "volume", volume);
        _setUintForOrder(hash, "minimumReturns", minimumReturns);
        _setAddressForOrder(hash, "creator", msg.sender);
        _setUintForOrder(hash, "status", uint256(OrderStatus.ONGOING));

        VaultInstance.moveToOrder(baseToken, volume, hash);

        emit OrderCreated(msg.sender, hash);
    }

    /**
     * @notice Creates a new market order.
     * @param baseToken Token to be sold.
     * @param quoteToken Token to be bought.
     * @param volume Amount of base token to be sold.
     * @param limitPrice Price of 10**18 quote tokens expressed in base token amount. How much of quote token will I get for 10**18 base tokens.
     * @param expirationTime Expiration time, must be 0 for no expiration time or larger than current time, elsewise function will revert.
     *
     * Function will fail if volume is less than or equal to zero, if limit price is less than or equal to 0 or if expiration time is invalid.
     */
    function createLimitOrder(
        address baseToken,
        address quoteToken,
        uint256 volume,
        uint256 limitPrice,
        uint256 expirationTime
    ) external {
        require(
            expirationTime == 0 || expirationTime > block.timestamp,
            "Invalid expiration time."
        );
        require(volume > 0, "Invalid volume provided.");
        require(limitPrice > 0, "Invalid limit price provided.");

        bytes32 hash = keccak256(
            abi.encodePacked(
                baseToken,
                quoteToken,
                volume,
                msg.sender,
                block.timestamp,
                uint256(OrderType.LIMIT_ORDER)
            )
        );

        _setUintForOrder(hash, "orderType", uint256(OrderType.LIMIT_ORDER));
        _setAddressForOrder(hash, "baseToken", baseToken);
        _setAddressForOrder(hash, "quoteToken", quoteToken);
        _setUintForOrder(hash, "volume", volume);
        _setUintForOrder(hash, "limitPrice", limitPrice);
        _setUintForOrder(hash, "expirationTime", expirationTime);
        _setAddressForOrder(hash, "creator", msg.sender);
        _setUintForOrder(hash, "status", uint256(OrderStatus.ONGOING));
        _setUintForOrder(hash, "filledBase", 0);

        VaultInstance.moveToOrder(baseToken, volume, hash);

        emit OrderCreated(msg.sender, hash);
    }

    /**
     * @notice Cancel ongoing non-expired order and return in-order funds to vault.
     * @param hash Hash of the order.
     *
     * Function will fail if order is expired, if order is finished or cancelled or if caller is not creator of the order.
     */
    function cancelOrder(bytes32 hash)
        external
        notExpired(hash)
        onlyOngoingOrders(hash)
    {
        require(
            msg.sender == _getCreator(hash),
            "Only order creator can cancel the order."
        );

        OrderType type_ = OrderType(_getOrderType(hash));

        uint256 amountLeft;

        if (type_ == OrderType.MARKET_ORDER) {
            amountLeft = _getVolume(hash);
        } else if (type_ == OrderType.LIMIT_ORDER) {
            amountLeft = _getVolume(hash) - _getFilledBase(hash);
        }

        VaultInstance.orderCancellation(_getBaseToken(hash), amountLeft, hash);

        _setUintForOrder(hash, "status", uint256(OrderStatus.CANCELLED));

        emit OrderCancelled(hash);
    }

    /**
     * @notice Reclaim funds from expired order.
     * @param hash Hash of the order.
     *
     * Function will fail if order is not expired, if order is finished or cancelled or if caller is not creator of the order nor the executor.
     */
    function reclaimExpiredFunds(bytes32 hash)
        external
        onlyExecutorAndCreator(hash)
        onlyLimitOrder(hash)
        onlyOngoingOrders(hash)
    {
        uint256 expTime = _getExpirationTime(hash);

        require(
            expTime < block.timestamp && expTime > 0,
            "Only expired orders can be reclaimed."
        );

        VaultInstance.orderExpiration(
            _getBaseToken(hash),
            (_getVolume(hash) - _getFilledBase(hash)),
            hash,
            _getCreator(hash)
        );

        _setUintForOrder(hash, "status", uint256(OrderStatus.EXPIRED));

        emit OrderExpired(hash);
    }

    /**
     * @notice Change expiration time for limit or stop loss order.
     * @param hash Hash of the order.
     * @param newTime New expiration time for the order.
     *
     * Function will fail if order is expired, if order is finished or cancelled, if caller is not creator of the order or if expiration time is invalid.
     */
    function prolongOrder(bytes32 hash, uint256 newTime)
        external
        onlyOngoingOrders(hash)
        notExpired(hash)
    {
        require(
            _getOrderType(hash) != uint256(OrderType.MARKET_ORDER),
            "Invalid order type."
        );
        require(
            msg.sender == _getCreator(hash),
            "Only creator of the order can prolong it."
        );
        require(
            newTime == 0 || newTime > block.timestamp,
            "Invalid expiration time provided."
        );

        _setUintForOrder(hash, "expirationTime", newTime);

        emit OrderChanged(hash);
    }

    /**
     * @dev Executes the order.
     * @param hash The hash of the order to be executed.
     * @param route An array of data that signals routes to be used for order execution, where each route is one dex.
     * @param routePairs An array with addresses of the Uniswap, Sushiswap and Curve StableSwap pools.
     * @return volume of base token filled in this execution, remaining order volume to be filled and total returns from this execution, total returns from this execution
     *
     * Route format is as follows -> [dex enum, amount of base token, minimum quote returns for this route, dex enum, amount of base token, minimum quote returns for this route...]
     * If route array contains Uniswap, Sushiswap or Curve dexs, then routePairs array should contain addresses of pool contracts for previous routes, in the same order the routes have been pushed to the route array.
     * Curve has 3 additional parameters added to route array. 4th and 5th parameters, those are the indexes of the base and quote tokens in that order, that are acquired from StableSwap pool contract (that is being used to execute route), via coins() array function getter.
     * 6th parameter is 0 or 1, and it signals wheter the StableSwap pool on which exhange will be executed returns returns or not. 0 means it does not return and 1 means it returns. If quote token on the pool is Compond CToken, but not in order, this flag must be set to 0 or else execution will revert.
     * Route for internal matching format is as follows -> [enum for internal matching, baseAmount, quoteAmount, secondOrderHash in uint256 format]
     * Transaction will revert if if order does not exist, if minimum returns for some route are not met, if sum or route volumes is greater than the total order volume, if route volume is less than or equal to zero, if one of pair contracts do not match order token pair, if caller is not executor, nor the creator of the order or if order is expired, finished or cancelled, if token indexes for Curve route are invalid in any way, if Curve route has 6th parameter set to 1, but quote asset is used as Compound CToken in this pair trade on Curve, but not in order.
     */
    function executeOrder(
        bytes32 hash,
        uint256[] memory route,
        address[] memory routePairs
    )
        internal
        orderExists(hash)
        onlyExecutorAndCreator(hash)
        onlyOngoingOrders(hash)
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(route.length > 0, "Route cannot be empty.");

        uint256[8] memory localsU; // this is solution for too large stack
        // localsU[0] is r counter
        // localsU[1] is rp counter
        // localsU[2] is totalReturns
        // localsU[3] is filledVolume
        // localsU[4] is remainingVolume
        // localsU[5] is amount of ETH received in WETH
        // localsU[6] is local returns for each dex
        // localsU[7] pool type for curve handler

        address[3] memory localsA = [
            // another too deep stack workaround
            _getBaseToken(hash), // localsA[0] is base token address
            _getQuoteToken(hash), // locals[1] is quote token address
            _getCreator(hash) // localsA[2] is creator address
        ];

        {
            localsU[4] = _getVolume(hash);

            if (OrderType(_getOrderType(hash)) == OrderType.LIMIT_ORDER)
                localsU[4] -= _getFilledBase(hash);
        }

        while (localsU[0] < route.length) {
            // route volume amount must not be zero or less
            require(
                route[localsU[0] + 1] > 0,
                "Route volume must be greater than zero."
            );
            require(
                route[localsU[0] + 1] <= localsU[4],
                "Invalid route, route volume amount exceeds total or remaining order volume."
            );

            localsU[3] += route[localsU[0] + 1]; // increase filledVolume by current route volume
            localsU[4] -= route[localsU[0] + 1]; // reduce remainingVolume by current route volume

            if (
                route[localsU[0]] == uint256(DEX.UNISWAPV2) ||
                route[localsU[0]] == uint256(DEX.SUSHISWAPV2)
            ) {
                {
                    VaultInstance.orderFill_ReleaseFunds(
                        localsA[2],
                        localsA[0],
                        route[localsU[0] + 1],
                        hash,
                        payable(routePairs[localsU[1]]), // pair
                        (localsA[0] == address(0)) // if base token is ethereum, wrap it
                    );

                    localsU[6] = IERC20(
                        (localsA[1] == address(0) ? weth : localsA[1]) // if quote token is Ethereum, then use WETH as a reference point
                    ).balanceOf(vault);

                    executeUniV2Swap(
                        routePairs[localsU[1]], // pair
                        localsA[0],
                        localsA[1],
                        route[localsU[0] + 2] // amountOut
                    ); // this will send tokens to the vault, they will be credited later

                    localsU[6] =
                        IERC20((localsA[1] == address(0) ? weth : localsA[1]))
                            .balanceOf(vault) -
                        localsU[6]; // calculate returns (_after - _before)

                    if (localsA[1] == address(0)) localsU[5] += localsU[6]; // if route is filled in WETH, increase amount of WETH to be reedemed for ETH at the moment of Vault order fill

                    require(
                        localsU[6] >= route[localsU[0] + 2], // _return >= amountOut
                        string(
                            abi.encodePacked(
                                "Returns from ",
                                (
                                    (route[localsU[0]] ==
                                        uint256(DEX.UNISWAPV2))
                                        ? "UniswapV2"
                                        : "SushiswapV2"
                                ),
                                " route are too low."
                            )
                        )
                    ); // check if returns are acceptable

                    localsU[2] += localsU[6]; // credit returns to total returns
                }

                localsU[1]++; // increment route pair counter, since uniswap used one
            } else if (route[localsU[0]] == uint256(DEX.BANCOR)) {
                {
                    VaultInstance.orderFill_ReleaseFunds(
                        localsA[2],
                        localsA[0],
                        route[localsU[0] + 1],
                        hash,
                        payable(address(this)),
                        false
                    );
                    // having block if/else will make larger bytecode, but will save gas during execution, since we will avoid inline conditional for instantiating base ERC20 in dependence of base asset being Ether...
                    if (localsA[0] != address(0)) {
                        // base token is just a classic ERC20...
                        IERC20(localsA[0]).safeApprove( // approve ERC20 for Bancor to use...
                            contractRegistry.addressOf(bancorNetworkName),
                            route[localsU[0] + 1]
                        );
                        localsU[6] = executeBancorTrade( // save returns of the route trade
                            IERC20(localsA[0]),
                            IERC20(
                                (
                                    localsA[1] == address(0)
                                        ? 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                                        : localsA[1]
                                )
                            ),
                            route[localsU[0] + 1]
                        );
                    } else {
                        // base asset is Ether
                        localsU[6] = executeBancorTrade( // save returns of the route trade
                            IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
                            IERC20(
                                (
                                    localsA[1] == address(0)
                                        ? 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                                        : localsA[1]
                                )
                            ),
                            route[localsU[0] + 1]
                        );
                    }

                    require(
                        localsU[6] >= route[localsU[0] + 2], // _return < amountOut
                        "Returns from Bancor route are too low."
                    ); // check if returns are acceptable

                    localsU[2] += localsU[6]; // credit returns to total returns
                }
            } else if (route[localsU[0]] == uint256(DEX.CURVE)) {
                VaultInstance.orderFill_ReleaseFunds(
                    localsA[2],
                    localsA[0],
                    route[localsU[0] + 1],
                    hash,
                    payable(address(this)),
                    false
                );

                if (localsA[0] != address(0))
                    IERC20(localsA[0]).safeApprove(
                        routePairs[localsU[1]],
                        route[localsU[0] + 1]
                    );

                if (localsA[1] != address(0)) {
                    localsU[6] = IERC20(localsA[1]).balanceOf(address(this));

                    executeCurveSwap(
                        routePairs[localsU[1]],
                        [route[localsU[0] + 3], route[localsU[0] + 4]],
                        localsA[0],
                        localsA[1],
                        route[localsU[0] + 1],
                        route[localsU[0] + 5]
                    );

                    localsU[6] =
                        IERC20(localsA[1]).balanceOf(address(this)) -
                        localsU[6];
                } else {
                    localsU[6] = executeCurveSwap(
                        routePairs[localsU[1]],
                        [route[localsU[0] + 3], route[localsU[0] + 4]],
                        localsA[0],
                        localsA[1],
                        route[localsU[0] + 1],
                        route[localsU[0] + 5]
                    );
                }

                require(
                    localsU[6] >= route[localsU[0] + 2], // _return < amountOut
                    "Returns from Curve route are too low."
                ); // check if returns are acceptable

                localsU[2] += localsU[6]; // credit returns to total returns
                localsU[0] += 3; // increment couter by 3, since curve has 3 additional route arguments
            } else if (route[localsU[0]] == uint256(DEX.INTERNAL)) {
                executeInternalSwap(
                    hash,
                    bytes32(route[localsU[0] + 3]),
                    route[localsU[0] + 1], // base amount
                    route[localsU[0] + 2] // quote amount
                );

                localsU[2] += route[localsU[0] + 2];
            } else revert("Invalid DEX identifier provided.");

            localsU[0] += 4;
        }

        require(
            localsU[2] >= _getMinimumReturns(hash),
            "Total returns too low."
        );

        VaultInstance.orderFill_Succeeded(
            localsA[2],
            localsA[1],
            localsU[2],
            hash,
            localsU[5]
        );

        emit OrderFill(hash, localsU[3], localsU[2]);

        return (localsU[3], localsU[4], localsU[2]);
    }

    /**
     * @notice Executes market order with provided routes. An external wrapper for executeOrder().
     * @dev Ideally should be called only from Executor component with the routes calculated by the Router component.
     * @param hash The hash of the order to be executed.
     * @param route An array of data that signals routes to be used for order execution, where each route is one dex.
     * @param routePairs An array with addresses of the pool used by Uniswap, Sushiswap and Curve based routes.
     *
     * For route and routePairs format, look into dev documentation for executeRoute().
     *
     * Transaction will revert if whole order is not filled or if order type is not market order. For additional revert cases, look into executeRoute() docs.
     */
    function executeMarketOrder(
        bytes32 hash,
        uint256[] calldata route,
        address[] calldata routePairs
    ) external onlyMarketOrder(hash) {
        (, uint256 _remainingVolume, ) = executeOrder(hash, route, routePairs);

        require(_remainingVolume == 0, "Market order must be filled 100%.");

        _setUintForOrder(hash, "status", uint256(OrderStatus.FINISHED));

        emit OrderFinished(hash);
    }

    /**
     * @notice Executes limit order with provided routes. An external wrapper for executeOrder().
     * @dev Ideally should be called only from Executor component with the routes calculated by the Router component.
     * @param hash The hash of the order to be executed.
     * @param route An array of data that signals routes to be used for order execution, where each route is one dex.
     * @param routePairs An array with addresses of the pool used by Uniswap, Sushiswap and Curve based routes.
     *
     * For route and routePairs format, look into dev documentation for executeRoute().
     *
     * Transaction will revert if order is expired or if order type is not limit order. For additional revert cases, look into executeRoute() docs.
     */
    function executeLimitOrder(
        bytes32 hash,
        uint256[] calldata route,
        address[] calldata routePairs
    ) external notExpired(hash) onlyLimitOrder(hash) {
        uint256 _filledVolume;
        uint256 _totalReturns;

        {
            uint256 _remainingVolume;

            (_filledVolume, _remainingVolume, _totalReturns) = executeOrder(
                hash,
                route,
                routePairs
            );

            {
                require(
                    _totalReturns >=
                        ((_getLimitPrice(hash) * _filledVolume) / (10**18)), // total returns of the fill must be greater or equal to (limitPrice * filled amount of base tokens / 10**18)
                    "Limit order returns are too low, according to limit price provided by the order creator."
                );
            }

            if (_remainingVolume == 0) {
                _setUintForOrder(hash, "status", uint256(OrderStatus.FINISHED));

                emit OrderFinished(hash);
            }
        }

        _setUintForOrder(
            hash,
            "filledBase",
            (_getFilledBase(hash) + _filledVolume)
        );
        _setUintForOrder(
            hash,
            "filledQuote",
            (_getFilledQuote(hash) + _totalReturns)
        );
    }

    // ORDER CREATION AND EXEUCTION LOGIC - END

    // INTERNAL STORAGE GETTERS - START

    /**
     * @dev Returns uint256 type number identifing order type per OrderType enumerator.
     * @param hash Hash of the order.
     * @return Number identifing order type per OrderType enumerator.
     */
    function _getOrderType(bytes32 hash)
        internal
        view
        override
        returns (uint256)
    {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "orderType"))
            );
    }

    /**
     * @dev Returns an address of the base token for the order.
     * @param hash Hash of the order.
     * @return An address of the base token.
     */
    function _getBaseToken(bytes32 hash)
        internal
        view
        override
        returns (address)
    {
        return
            StorageInstance.getAddress(
                keccak256(abi.encodePacked("orders", hash, "baseToken"))
            );
    }

    /**
     * @dev Returns an address of the quote token for the order.
     * @param hash Hash of the order.
     * @return An address of the quote token.
     */
    function _getQuoteToken(bytes32 hash)
        internal
        view
        override
        returns (address)
    {
        return
            StorageInstance.getAddress(
                keccak256(abi.encodePacked("orders", hash, "quoteToken"))
            );
    }

    /**
     * @dev Returns volume of the order in base token.
     * @param hash Hash of the order.
     * @return The volume of the order.
     */
    function _getVolume(bytes32 hash) internal view override returns (uint256) {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "volume"))
            );
    }

    /**
     * @dev Returns limit price of the order.
     * @param hash Hash of the order.
     * @return The limit price.
     */
    function _getLimitPrice(bytes32 hash)
        internal
        view
        override
        returns (uint256)
    {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "limitPrice"))
            );
    }

    function _getOrderCreator(bytes32 hash)
        internal
        view
        override
        returns (address)
    {
        return
            StorageInstance.getAddress(
                keccak256(abi.encodePacked("orders", hash, "creator"))
            );
    }

    /**
     * @dev Returns an expiration time of the order.
     * @param hash Hash of the order.
     * @return The expiration time.
     */
    function _getExpirationTime(bytes32 hash) internal view returns (uint256) {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "expirationTime"))
            );
    }

    /**
     * @dev Returns minimum returns of order.
     * @param hash Hash of the order.
     * @return The minimum returns of quote token for the order.
     */
    function _getMinimumReturns(bytes32 hash)
        internal
        view
        override
        returns (uint256)
    {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "minimumReturns"))
            );
    }

    /**
     * @dev Returns an address of order creator.
     * @param hash Hash of the order.
     * @return An address of the order creator.
     */
    function _getCreator(bytes32 hash) internal view returns (address) {
        return
            StorageInstance.getAddress(
                keccak256(abi.encodePacked("orders", hash, "creator"))
            );
    }

    /**
     * @dev Returns an uint256 representing OrderStatus enum.
     * @param hash Hash of the order.
     * @return Order status.
     */
    function _getOrderStatus(bytes32 hash)
        internal
        view
        override
        returns (uint256)
    {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "status"))
            );
    }

    /**
     * @dev Returns an uint256 representing filled base token.
     * @param hash Hash of the order.
     * @return Amount filled base token.
     */
    function _getFilledBase(bytes32 hash)
        internal
        view
        override
        returns (uint256)
    {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "filledBase"))
            );
    }

    /**
     * @dev Returns an uint256 representing filled quote token.
     * @param hash Hash of the order.
     * @return Amount filled quote token.
     */
    function _getFilledQuote(bytes32 hash)
        internal
        view
        override
        returns (uint256)
    {
        return
            StorageInstance.getUint(
                keccak256(abi.encodePacked("orders", hash, "filledQuote"))
            );
    }

    // INTERNAL STORAGE GETTERS - END

    // ORDER INFO GETTERS FOR FRONTEND - START
    // These should not be used in contracts, but only on frontend.

    /**
     * @notice Returns order type based on the has of the order.
     * @param hash Hash of the order.
     * @return String identifying type of the order.
     *
     * This function will revert if order hash does not identify existing order.
     */
    function getOrderTypeByHash(bytes32 hash)
        external
        view
        orderExists(hash)
        returns (string memory)
    {
        if (_getOrderType(hash) == uint256(OrderType.MARKET_ORDER)) {
            return "MARKET_ORDER";
        } else return "LIMIT_ORDER";
    }

    /**
     * @notice Returns information about limit order.
     * @dev Passed hash must be the hash of the limit order or else function will fail.
     * @param hash Hash of the order.
     * @return base token address, quote token address, order volume, order limit price, order expiration time, amount of base token filled
     *
     * This function will fail if order does not exist or if order type is not limit order.
     */
    function getLimitOrder(bytes32 hash)
        external
        view
        orderExists(hash)
        onlyLimitOrder(hash)
        returns (
            address,
            address,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _getBaseToken(hash),
            _getQuoteToken(hash),
            _getVolume(hash),
            _getLimitPrice(hash),
            _getExpirationTime(hash),
            _getFilledBase(hash)
        );
    }

    /**
     * @notice Returns remaining information about limit order, that cannot be sent via getLimitOrder() function, bacause of EVM stack limitations.
     * @dev Passed hash must be the hash of the limit order or else function will fail.
     * @param hash Hash of the order.
     * @return amount of quote token filled
     *
     * This function will fail if order does not exist or if order type is not limit order.
     */
    function getLimitOrder_EXTENDED(bytes32 hash)
        external
        view
        orderExists(hash)
        onlyLimitOrder(hash)
        returns (uint256)
    {
        return _getFilledQuote(hash);
    }

    /**
     * @notice Returns information about market order.
     * @dev Passed hash must be the hash of the market order or else function will fail.
     * @param hash Hash of the order.
     * @return base token address, quote token address, order volume, total minimum returns of the order
     *
     * This function will fail if order does not exist or if order type is not market order.
     */
    function getMarketOrder(bytes32 hash)
        external
        view
        orderExists(hash)
        onlyMarketOrder(hash)
        returns (
            address,
            address,
            uint256,
            uint256
        )
    {
        return (
            _getBaseToken(hash),
            _getQuoteToken(hash),
            _getVolume(hash),
            _getMinimumReturns(hash)
        );
    }

    /**
     * @notice Get the status of the order.
     * @param hash Hash of the order.
     * @return Returns string identifying current state/status of the order.
     *
     * This function will fail if order does not exist.
     * This function won't return EXPIRED order status if order is expried, that should be checked on frontend.
     */
    function getOrderStatus(bytes32 hash)
        external
        view
        orderExists(hash)
        returns (string memory)
    {
        if (_getOrderStatus(hash) == uint256(OrderStatus.ONGOING))
            return "ONGOING";
        if (_getOrderStatus(hash) == uint256(OrderStatus.FINISHED))
            return "FINISHED";
        if (_getOrderStatus(hash) == uint256(OrderStatus.CANCELLED))
            return "CANCELLED";
    }

    // ORDER INFO GETTERS FOR FRONTEND - START

    // OTHER EXTERNAL GETTERS - START

    function getStorageAddr() external view returns (address) {
        return storage_;
    }

    function getVaultAddr() external view returns (address) {
        return vault;
    }

    // OTHER EXTERNAL GETTERS - END

    // INTERNAL SETTERS - START

    function _setUintForOrder(
        bytes32 hash,
        string memory property,
        uint256 value
    ) internal {
        StorageInstance.setUint(
            keccak256(abi.encodePacked("orders", hash, property)),
            value
        );
    }

    function _setAddressForOrder(
        bytes32 hash,
        string memory property,
        address value
    ) internal {
        StorageInstance.setAddress(
            keccak256(abi.encodePacked("orders", hash, property)),
            value
        );
    }

    // INTERNAL SETTERS - END

    fallback() external payable {}
}