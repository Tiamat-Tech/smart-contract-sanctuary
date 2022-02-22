// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import {SafeERC20, IERC20} from "SafeERC20.sol";
import {ISwapRouter} from "ISwapRouter.sol";

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
    IUniswapV2Router02 immutable sushiRouter;
    IUniswapRouter immutable uniswapRouter;

    event TransferSent(address _from, address _destAddr, uint _amount);

    constructor(address _sushiRouterAddress, address _uniRouterAddress) {
        sushiRouter = IUniswapV2Router02(_sushiRouterAddress);
        uniswapRouter = IUniswapRouter(_uniRouterAddress);
        owner = address(msg.sender);
    }

    receive() payable external {}

    modifier onlyOwner {
        require(msg.sender == owner, "Only contract creator is allow to call this function");
        _;
    }

    modifier checkPaths(address[] calldata sushiPath, address[] calldata uniPath) {
        require(sushiPath.length == 2 || sushiPath.length == 3, "Sushiswap path require 2 or 3 addresses");
        require(uniPath.length == 2 || uniPath.length == 3, "Uniswap path require 2 or 3 addresses");
        _;
    }

    function withdraw() onlyOwner external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function transferERC20(IERC20 token, address to, uint256 amount) onlyOwner external {
        uint256 erc20balance = token.balanceOf(address(this));
        require(amount <= erc20balance, "balance is low");
        emit TransferSent(msg.sender, to, amount);
        token.safeTransfer(to, amount);
    }

    function getBalanceERC20(IERC20 token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // slither-disable-next-line unused-return
    function _tradeOnSushi(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) private {
        address recipient = address(this);

        sushiRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            recipient,
            deadline
        );
    }

    // slither-disable-next-line unused-return
    function _tradeOnUniswap(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) private {
        uint24 fee = 3000;
        address recipient = address(this);
        uint160 sqrtPriceLimitX96 = 0;
        bytes memory abiPath;

        if (path.length == 2) {
            abiPath = abi.encodePacked(path[0], fee, path[1]);
        } else {
            abiPath = abi.encodePacked(path[0], fee, path[1], fee, path[2]);
        }

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: abiPath,
            recipient: address(this),
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin
        });

        uniswapRouter.exactInput(params);
        uniswapRouter.refundETH();
    }

    function buySushiSellUni(
            uint256 amountIn,
            uint256 amountOutMinSushi,
            uint256 amountOutMinUni,
            address[] calldata sushiPath,
            address[] calldata uniPath
        ) external onlyOwner checkPaths(sushiPath, uniPath) {
        uint256 deadline = block.timestamp;

        _tradeOnSushi(amountIn, amountOutMinSushi, sushiPath,  deadline);
        _tradeOnUniswap(IERC20(sushiPath[sushiPath.length - 1]).balanceOf(address(this)), amountOutMinUni, uniPath, deadline);
    }

    function buyUniSellSushi(
            uint256 amountIn,
            uint256 amountOutMinUni,
            uint256 amountOutMinSushi,
            address[] calldata uniPath,
            address[] calldata sushiPath
        ) external onlyOwner checkPaths(sushiPath, uniPath) {
        uint256 deadline = block.timestamp;

        _tradeOnUniswap(amountIn, amountOutMinUni, uniPath, deadline);
        _tradeOnSushi(IERC20(sushiPath[0]).balanceOf(address(this)), amountOutMinSushi, sushiPath,  deadline);
    }

    function allowTokenOnSushi(address tokenAddress) external {
        IERC20(tokenAddress).safeApprove(address(sushiRouter), type(uint256).max);
    }

    function allowTokenOnUni(address tokenAddress) external {
        IERC20(tokenAddress).safeApprove(address(uniswapRouter), type(uint256).max);
    }
}