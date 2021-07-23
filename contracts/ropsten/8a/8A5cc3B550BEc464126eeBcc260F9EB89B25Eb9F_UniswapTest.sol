// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.7.6;

import "./libraries/LibUniswapV3.sol";

contract UniswapTest {
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint8 maxPercentChange
    ) external {
        uint24[] memory poolFees = new uint24[](3);
        poolFees[0] = 500;
        poolFees[1] = 3000;
        poolFees[2] = 10000;

        uint32[] memory secondsAgosReference = new uint32[](2);
        secondsAgosReference[0] = 9 * 24 * 60 * 60;
        secondsAgosReference[1] = 60;

        (bool exists, ) =
            LibUniswapV3.swapExactInput(
                tokenIn,
                tokenOut,
                amountIn,
                poolFees,
                secondsAgosReference,
                maxPercentChange
            );
        require(exists, "not exists");
    }
}