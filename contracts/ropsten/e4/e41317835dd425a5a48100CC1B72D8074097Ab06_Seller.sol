// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/contracts/access/Ownable.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {SafeMath} from "./SafeMath.sol";

contract Seller is Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 private router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function approve(IERC20 token, uint256 amount) public onlyOwner {
        token.approve(address(router), amount);
    }

    function sell(IERC20 token, uint256 amountIn) public payable onlyOwner {
        token.transferFrom(msg.sender, address(this), amountIn);
        token.approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = router.WETH();

        router.swapExactTokensForETH(
            amountIn,
            1,
            path,
            address(this),
            block.timestamp + 600
        );
    }

    function buy(
        IERC20 token,
        uint256 amount,
        uint256 amountOutMin
    ) public payable onlyOwner {
        address[] memory path = new address[](2);
        path[1] = address(token);
        path[0] = router.WETH();

        router.swapExactETHForTokens{value: amount}(
            amountOutMin, // The minimum amount of output tokens that must be received for the transaction not to revert.
            path,
            address(this),
            block.timestamp + 1
        );
    }

    function withdrawEth(uint256 amount) external payable onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function withdraw(IERC20 token, uint256 amount) external onlyOwner {
        token.transfer(msg.sender, amount);
    }

    function close() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }
}