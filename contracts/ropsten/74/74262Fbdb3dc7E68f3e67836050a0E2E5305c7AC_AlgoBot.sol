// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "SafeERC20.sol";
import "ISwapRouter.sol";



interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
}

contract AlgoBot {
    using SafeERC20 for IERC20;
    address public owner;
    IUniswapV2Router02 private sushiRouter;
    IUniswapRouter private uniswapRouter;
    address private WETH;

    event TransferSent(address _from, address _destAddr, uint _amount);

    constructor(address _sushiAddress, address _uniRouterAddress, address _wethAddress) {
        sushiRouter = IUniswapV2Router02(_sushiAddress);
        uniswapRouter = IUniswapRouter(_uniRouterAddress);
        WETH = _wethAddress;
        owner = payable(msg.sender);
    }

    receive() payable external {}

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function withdraw() payable onlyOwner external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function transferERC20(IERC20 token, address to, uint256 amount) onlyOwner public {
        uint256 erc20balance = token.balanceOf(address(this));
        require(amount <= erc20balance, "balance is low");
        token.transfer(to, amount);
        emit TransferSent(msg.sender, to, amount);
    }

    function getBalanceERC20(IERC20 token) public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _tradeOnSushi(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) private {
        address recipient = address(this);

        sushiRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            _getPathForSushiSwap(tokenIn, tokenOut),
            recipient,
            deadline
        );
    }

    function _getPathForSushiSwap( address tokenIn, address tokenOut) private view returns (address[] memory) {
        address[] memory path;
        if (tokenIn == WETH || tokenOut == WETH) {
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
        } else {
            path = new address[](3);
            path[0] = tokenIn;
            path[1] = WETH;
            path[2] = tokenOut;
        }

        return path;
    }

    function _tradeOnUniswap(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) private {
        uint24 fee = 3000;
        address recipient = address(this);
        uint160 sqrtPriceLimitX96 = 0;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            tokenIn,
            tokenOut,
            fee,
            recipient,
            deadline,
            amountIn,
            amountOutMin,
            sqrtPriceLimitX96
        );

        uniswapRouter.exactInputSingle(params);
        uniswapRouter.refundETH();

        // refund leftover ETH to user
        (bool success,) = msg.sender.call{ value: address(this).balance }("");
        require(success, "refund failed");
    }

    function buySushiSellUni(
            uint256 amountIn,
            uint256 amountOutMinSushi,
            uint256 amountOutMinUni,
            address tokenInSushi,
            address tokenOutSushi,
            address tokenOutUni
        ) external onlyOwner {
        uint256 deadline = block.timestamp + 300;

        _tradeOnSushi(amountIn, amountOutMinSushi, tokenInSushi, tokenOutSushi,  deadline);
        _tradeOnUniswap(IERC20(tokenOutSushi).balanceOf(address(this)), amountOutMinUni, tokenOutSushi, tokenOutUni, deadline);
    }

    function buyUniSellSushi(
            uint256 amountIn,
            uint256 amountOutMinUni,
            uint256 amountOutMinSushi,
            address tokenInUni,
            address tokenOutUni,
            address tokenOutSushi
        ) external onlyOwner {
        uint256 deadline = block.timestamp + 300;

        _tradeOnUniswap(amountIn, amountOutMinUni, tokenInUni, tokenOutUni, deadline);
        _tradeOnSushi(IERC20(tokenOutUni).balanceOf(address(this)), amountOutMinSushi, tokenOutUni, tokenOutSushi,  deadline);
    }

    function allowTokenOnSushi(address tokenAddress) external {
        IERC20(tokenAddress).safeApprove(address(sushiRouter), type(uint256).max);
    }

    function allowTokenOnUni(address tokenAddress) external {
        IERC20(tokenAddress).safeApprove(address(uniswapRouter), type(uint256).max);
    }
}