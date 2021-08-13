//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/uniswapv3/ISwapRouter.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITokenExchange.sol";

contract UniswapV3TokenExchange is ITokenExchange, AccessControlEnumerableUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    event SellToken(address inputToken, address outputToken, uint256 amountIn, uint256 amountOut);
    struct TokenPair {
        uint64 slippage; // number less than 1e18, 1e18 == 100%, 1e15 = 0.1%
        IPriceOracle priceOracle;
        uint24 feePool;
        bool multihop;
        bytes route;
    }

    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    ISwapRouter public router;

    mapping(IERC20MetadataUpgradeable => mapping(IERC20MetadataUpgradeable => TokenPair)) public tokenPairs;

    function initialize(address router_) public initializer {
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
        tokenPairs[input_][output_] = TokenPair(slippage, priceOracle, feePool, multihop, route_);
    }

    function sellExactInput(
        IERC20MetadataUpgradeable inputToken,
        IERC20MetadataUpgradeable outputToken,
        address recipient,
        uint256 amountIn_
    ) external override onlyRole(STRATEGY_ROLE) returns (uint256) {
        // require
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
        uint256 output = router.exactInput(params);
        emit SellToken(address(inputToken), address(outputToken), amountIn_, output);
        return output;
    }
}