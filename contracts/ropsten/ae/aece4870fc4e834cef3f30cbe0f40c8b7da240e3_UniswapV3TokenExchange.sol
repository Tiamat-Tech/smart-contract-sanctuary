//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/uniswapV3/ISwapRouter.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITokenExchange.sol";

/**
 * @title contract used for swaping tokens on Uniswap V3
 */
contract UniswapV3TokenExchange is ITokenExchange, AccessControlEnumerableUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    /**
     * @notice TokenPair
     * @param slippage number less than 1e18, 1e18 == 100%, 1e15 = 0.1%
     * @param priceOracle reference to price oracle contract
     * @param feePool could be 500, 3000, or 10000
     * @param multihop allow multihop or not on V3
     * @param route trading path from IN token to OUT token
     */
    struct TokenPair {
        uint64 slippage;
        IPriceOracle priceOracle;
        uint24 feePool;
        bool multihop;
        bytes route;
    }

    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    ISwapRouter public router;

    mapping(IERC20MetadataUpgradeable => mapping(IERC20MetadataUpgradeable => TokenPair)) public tokenPairs;
    mapping(IERC20MetadataUpgradeable => mapping(IERC20MetadataUpgradeable => bool)) public isRegistered;

    function initialize(address router_) public initializer {
        require(router_ != address(0), "router address is 0");
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        router = ISwapRouter(router_);
    }

    function setTokenPair(
        IERC20MetadataUpgradeable input_,
        IERC20MetadataUpgradeable output_,
        IPriceOracle priceOracle,
        uint64 slippage,
        uint24 feePool,
        bool multihop,
        bytes memory route_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(input_) != address(0), "input address is 0");
        require(address(output_) != address(0), "input address is 0");
        require(address(priceOracle) != address(0), "priceOracle address is 0");

        tokenPairs[input_][output_] = TokenPair(slippage, priceOracle, feePool, multihop, route_);
        isRegistered[input_][output_] = true;
    }

    function sellExactInput(
        IERC20MetadataUpgradeable inputToken,
        IERC20MetadataUpgradeable outputToken,
        address recipient,
        uint256 amountIn_
    ) external override onlyRole(STRATEGY_ROLE) returns (uint256 amountOut_) {
        require(address(inputToken) != address(0), "inputToken address is 0");
        require(address(outputToken) != address(0), "outputToken address is 0");
        require(isRegistered[inputToken][outputToken], "token pair not registered");
        require(recipient != address(0), "recipient is address 0");
        require(amountIn_ > 0, "amount is 0");

        inputToken.safeTransferFrom(_msgSender(), address(this), amountIn_);
        inputToken.safeIncreaseAllowance(address(router), amountIn_);
        TokenPair storage tp = tokenPairs[inputToken][outputToken];
        uint256 price = tp.priceOracle.price(address(inputToken));
        uint8 dec = tp.priceOracle.decimals();
        uint256 exactAmount = (amountIn_ * price * 10**outputToken.decimals()) / 10**inputToken.decimals() / 10**dec;
        uint256 amountOutMinimum = (exactAmount * (1e18 - tp.slippage)) / 1e18;

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: tp.route,
                recipient: recipient,
                deadline: block.timestamp + 1,
                amountIn: amountIn_,
                amountOutMinimum: amountOutMinimum
            });

        // Executes the swap.
        amountOut_ = router.exactInput(params);
        emit SellToken(address(inputToken), address(outputToken), amountIn_, amountOut_);
    }
}