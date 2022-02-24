// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract TokenLiquidator {
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // Mainnet
    // address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Ropsten
    address private constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    IUniswapV2Router02 public uniswapV2Router =
        IUniswapV2Router02(UNISWAP_V2_ROUTER);
    IUniswapV2Factory public uniswapV2Factory =
        IUniswapV2Factory(UNISWAP_V2_FACTORY);

    event AddedLiquidity(
        uint256 indexed amountA,
        uint256 indexed amountB,
        uint256 indexed liquidity
    );

    function provideLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amount
    ) external {
        // Transfer tokens from the caller to this contract
        IERC20(_tokenA).transferFrom(msg.sender, address(this), _amount);

        // Half tokens in tokenA and other half to be swapped.
        uint256 amountA = _amount / 2;
        uint256 amountB;

        uint256[] memory amounts = _swap(_tokenA, _tokenB, amountA, 1);
        // amountB after swapping half of tokenA amount.
        amountB = amounts[amounts.length - 1];

        // Add liquidity and send LP tokens to caller.
        _addLiquidity(_tokenA, _tokenB, amountA, amountB, msg.sender);
    }

    function _swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) internal returns (uint256[] memory amounts) {
        // Approve uniswapRouter to use the tokens.
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }

        amounts = uniswapV2Router.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            address(this),
            block.timestamp + 3600 * 2
        );

        return amounts;
    }

    function _addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        address _to
    ) internal {
        IERC20(_tokenA).approve(UNISWAP_V2_ROUTER, _amountA);
        IERC20(_tokenB).approve(UNISWAP_V2_ROUTER, _amountB);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = uniswapV2Router
            .addLiquidity(
                _tokenA,
                _tokenB,
                _amountA,
                _amountB,
                1,
                1,
                _to,
                block.timestamp + 3600 * 2
            );

        emit AddedLiquidity(amountA, amountB, liquidity);
    }

    function _removeLiquidity(address _tokenA, address _tokenB)
        internal
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = getPairAddress(_tokenA, _tokenB);

        uint256 liquidity = IERC20(pair).balanceOf(address(this));

        IERC20(pair).approve(UNISWAP_V2_ROUTER, liquidity);

        (amountA, amountB) = uniswapV2Router.removeLiquidity(
            _tokenA,
            _tokenB,
            liquidity,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function getPairAddress(address _tokenA, address _tokenB)
        public
        view
        returns (address pair)
    {
        return uniswapV2Factory.getPair(_tokenA, _tokenB);
    }

    function getLiquidity(address _pairAddress, address _user)
        public
        view
        returns (uint256 liquidity)
    {
        return IERC20(_pairAddress).balanceOf(_user);
    }
}