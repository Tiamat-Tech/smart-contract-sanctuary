// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20Detailed} from "../interfaces/IERC20Detailed.sol";
import {IUniswapRouter} from "../interfaces/uniswap/IUniswapRouter.sol";
import {IMockMinter} from "./MockStablecoins.sol";

contract MockUniswapRouter is Context, IUniswapRouter {
    using SafeERC20 for IERC20;

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        address src = path[0];
        IERC20(src).safeTransferFrom(_msgSender(), address(this), amountIn);

        address dest = path[path.length - 1];
        IMockMinter(dest).mint(to, 100 * (10 ** IERC20Detailed(dest).decimals()));
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = 100 * (10 ** IERC20Detailed(dest).decimals());
    }
}