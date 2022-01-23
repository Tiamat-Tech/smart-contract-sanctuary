pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../external/IUniswapV2Router02.sol";

contract UniswapRouterMock is IUniswapV2Router02 {
    string public lastErr;

    event TokenForToken(uint256 amountOut, uint256 amountInMax, address fromToken, address toToken);
    event TokenForNative(uint256 amountOut, uint256 amountInMax, address fromToken);
    event NativeForToken(uint256 amountOut, uint256 amountInMax, address toToken);

    constructor () {
        lastErr = "";
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    override external
    returns (uint[] memory amounts) {
        lastErr = string(abi.encodePacked("swapTokensForExactETH ", Strings.toHexString(amountOut), ", ", Strings.toHexString(amountInMax), ", [", Strings.toHexString(uint160(path[0]), 20), ", ", Strings.toHexString(uint160(path[1]), 20), "], ", Strings.toHexString(uint160(to), 20)));

        emit TokenForToken(amountOut, amountInMax, path[0], path[1]);
        return new uint[](1);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) override external returns (uint[] memory amounts) {
        lastErr = string(abi.encodePacked("swapTokensForExactTokens ", Strings.toHexString(amountOut), ", ", Strings.toHexString(amountInMax), ", [", Strings.toHexString(uint160(path[0]), 20), ", ", Strings.toHexString(uint160(path[1]), 20), "], ", Strings.toHexString(uint160(to), 20)));

        emit TokenForNative(amountOut, amountInMax, path[0]);
        return new uint[](1);
    }

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    override external
    payable
    returns (uint[] memory amounts) {
        lastErr = string(abi.encodePacked("swapETHForExactTokens ", Strings.toHexString(amountOut), ", ", Strings.toHexString(msg.value), ", [", Strings.toHexString(uint160(path[0]), 20), ", ", Strings.toHexString(uint160(path[1]), 20), "], ", Strings.toHexString(uint160(to), 20)));

        emit NativeForToken(amountOut, msg.value, path[0]);
        return new uint[](1);
    }

    // NOT REQUIRED IN TESTS


    // UNI V1

    function factory() override external pure returns (address) {
        return address(0);
    }

    function WETH() override external pure returns (address) {
        return address(0);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) override external returns (uint amountA, uint amountB, uint liquidity) {
        return (0, 0, 0);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) override external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        return (0, 0, 0);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) override external returns (uint amountA, uint amountB) {
        return (0, 0);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) override external returns (uint amountToken, uint amountETH) {
        return (0, 0);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) override external returns (uint amountA, uint amountB) {
        return (0, 0);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) override external returns (uint amountToken, uint amountETH) {
        return (0, 0);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) override external returns (uint[] memory amounts) {
        return new uint[](1);
    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    override external
    payable
    returns (uint[] memory amounts) {
        return new uint[](1);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    override external
    returns (uint[] memory amounts) {
        return new uint[](1);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) override external pure returns (uint amountB) {
        return 0;
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) override external pure returns (uint amountOut) {
        return 0;
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) override external pure returns (uint amountIn) {
        return 0;
    }

    function getAmountsOut(uint amountIn, address[] calldata path) override external view returns (uint[] memory amounts) {
        return new uint[](1);
    }

    function getAmountsIn(uint amountOut, address[] calldata path) override external view returns (uint[] memory amounts) {
        return new uint[](1);
    }

    // UNI V2
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) override external returns (uint amountETH) {
        return 0;
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) override external returns (uint amountETH) {
        return 0;
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) override external {}

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) override external payable {}

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) override external {}
}