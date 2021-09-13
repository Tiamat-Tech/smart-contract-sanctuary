//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/uniswapV2/IUniswapV2Router02.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/ITokenExchange.sol";

contract UniswapV2TokenExchange is ITokenExchange, AccessControlEnumerableUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    struct V2TokenPair {
        uint64 slippage; // number less than 1e18, 1e18 == 100%, 1e15 = 0.1%
        IPriceOracle priceOracle;
        bool multihop;
        address[] path;
    }

    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");
    IUniswapV2Router02 public router;

    mapping(IERC20MetadataUpgradeable => mapping(IERC20MetadataUpgradeable => V2TokenPair)) public tokenPairs;
    mapping(IERC20MetadataUpgradeable => mapping(IERC20MetadataUpgradeable => bool)) public isRegistered;

    function initialize(address router_) public initializer {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        router = IUniswapV2Router02(router_);
    }

    /**
     * @dev set a token pair to be traded on Uniswap V2 (or equivalent)
     * @param input_ input ERC20 token
     * @param output_ output ERC20 token
     * @param priceOracle price oracle that implements IPriceOracle
     * @param slippage slippage
     * @param multihop true if `path` is multihop (indirect) swapping, false otherwise
     * @param path array of token addresses for the swap
     * NOTE: `path.length` must be >= 2.
     *       Pools for each consecutive pair of addresses must exist and have liquidity.
     *       `path` must start with `address(input)` and end with `address(output)`.
     */
    function setTokenPair(
        IERC20MetadataUpgradeable input_,
        IERC20MetadataUpgradeable output_,
        IPriceOracle priceOracle,
        uint64 slippage,
        bool multihop,
        address[] calldata path
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(path[0] == address(input_), "path start is not input token");
        require(path[path.length - 1] == address(output_), "path destination is not output token");
        tokenPairs[input_][output_] = V2TokenPair(slippage, priceOracle, multihop, path);
        isRegistered[input_][output_] = true;
    }

    function sellExactInput(
        IERC20MetadataUpgradeable inputToken,
        IERC20MetadataUpgradeable outputToken,
        address recipient,
        uint256 amountIn_
    ) external override onlyRole(STRATEGY_ROLE) returns (uint256) {
        require(isRegistered[inputToken][outputToken], "token pair not registered");
        require(recipient != address(0), "recipient is address 0");
        require(amountIn_ > 0, "amount is 0");
        inputToken.safeTransferFrom(_msgSender(), address(this), amountIn_);
        inputToken.safeIncreaseAllowance(address(router), amountIn_);
        V2TokenPair storage tp = tokenPairs[inputToken][outputToken];
        uint256 price = tp.priceOracle.price(address(inputToken));

        uint8 dec = tp.priceOracle.decimals();
        uint256 exactAmount = (amountIn_ * price * 10**outputToken.decimals()) / 10**(inputToken.decimals() + dec);
        uint256 amountOutMinimum = (exactAmount * (1e18 - tp.slippage)) / 1e18;

        // Executes the swap.
        uint256[] memory amounts =
            router.swapExactTokensForTokens(amountIn_, amountOutMinimum, tp.path, recipient, block.timestamp + 1);
        uint256 output = amounts[tp.path.length - 1];
        emit SellToken(address(inputToken), address(outputToken), amountIn_, output);
        return output;
    }
}