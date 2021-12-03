// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./ISwaper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Swaper is ISwaper, Context, Ownable {
    //ropsten router address
    address public UNISWAP_ROUTER_ADDRESS =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address public UNISWAP_FACTORY_ADDRESS =
        0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351;

    function addLiquidity(
        address _inputTokenAddress,
        address _outputTokenAddress,
        uint256 _amountInputToken,
        uint256 _amountOutputToken,
        uint256 _minimumAmountInputToken,
        uint256 _minimumAmountOutputToken,
        uint256 _expireTime
    ) public virtual override returns (bool) {
        require(
            _expireTime > block.timestamp,
            "expire time should be in the future"
        );
        _validateAndTransferRouterAllowance(
            _inputTokenAddress,
            _amountInputToken
        );
        _validateAndTransferRouterAllowance(
            _outputTokenAddress,
            _amountOutputToken
        );
        _addLiquidity(
            _inputTokenAddress,
            _outputTokenAddress,
            _amountInputToken,
            _amountOutputToken,
            _minimumAmountInputToken,
            _minimumAmountOutputToken,
            _expireTime
        );
        return true;
    }

    function _addLiquidity(
        address _inputTokenAddress,
        address _outputTokenAddress,
        uint256 _amountInputToken,
        uint256 _amountOutputToken,
        uint256 _minimumAmountInputToken,
        uint256 _minimumAmountOutputToken,
        uint256 _expireTime
    ) internal returns (bool) {
        uint256 amountA;
        uint256 amountB;
        uint256 liquidity;
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            UNISWAP_ROUTER_ADDRESS
        );
        (amountA, amountB, liquidity) = uniswapRouter.addLiquidity(
            _inputTokenAddress,
            _outputTokenAddress,
            _amountInputToken,
            _amountOutputToken,
            _minimumAmountInputToken,
            _minimumAmountOutputToken,
            _msgSender(),
            _expireTime
        );
        emit liquidityEvent(
            _inputTokenAddress,
            _outputTokenAddress,
            _msgSender(),
            amountA,
            amountB,
            liquidity
        );
        return true;
    }

    function removeLiquidity(
        address _inputTokenAddress,
        address _outputTokenAddress,
        uint256 _minimumAmountInputToken,
        uint256 _minimumAmountOutputToken,
        uint256 _expireTime
    ) public virtual override returns (bool) {
        uint256 amountA;
        uint256 amountB;
        address pair = IUniswapV2Factory(UNISWAP_FACTORY_ADDRESS).getPair(
            _inputTokenAddress,
            _outputTokenAddress
        );

        uint256 _liquidity = IERC20(pair).balanceOf(address(this));

        require(
            _expireTime > block.timestamp,
            "expire time should be in the future"
        );

        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            UNISWAP_ROUTER_ADDRESS
        );

        (amountA, amountB) = uniswapRouter.removeLiquidity(
            _inputTokenAddress,
            _outputTokenAddress,
            _liquidity,
            _minimumAmountInputToken,
            _minimumAmountOutputToken,
            _msgSender(),
            _expireTime
        );

        emit liquidityEvent(
            _inputTokenAddress,
            _outputTokenAddress,
            _msgSender(),
            amountA,
            amountB,
            _liquidity
        );

        return true;
    }

    function swapTokens(
        address[] memory path,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _expireTime,
        address _to
    ) public virtual override returns (bool) {
        require(
            _expireTime > block.timestamp,
            "expire time should be in the future"
        );
        _validateAndTransferRouterAllowance(path[0], _amountIn);
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(
            UNISWAP_ROUTER_ADDRESS
        );
        uniswapRouter.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            path,
            _to,
            _expireTime
        );
        return true;
    }

    function _validateAndTransferRouterAllowance(
        address _tokenAddress,
        uint256 _amount
    ) internal {
        IERC20 token = IERC20(_tokenAddress);
        token.transferFrom(_msgSender(), address(this), _amount);
        token.approve(UNISWAP_ROUTER_ADDRESS, _amount);
    }
}