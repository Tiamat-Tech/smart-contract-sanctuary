// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Detailed} from "../interfaces/IERC20Detailed.sol";
import {IUniswapRouter} from "../interfaces/uniswap/IUniswapRouter.sol";
import {IMockMinter} from "./MockStablecoins.sol";

contract MockUniswapRouter is IUniswapRouter {
    function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata path,
        address to,
        uint256
    ) external override returns (uint256[] memory amounts) {
        address dest = path[path.length - 1];
        IMockMinter(dest).mint(to, 100 * (10 ** IERC20Detailed(dest).decimals()));
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = 100 * (10 ** IERC20Detailed(dest).decimals());
    }
}