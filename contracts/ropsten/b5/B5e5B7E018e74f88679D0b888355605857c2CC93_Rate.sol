// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract Rate {
    address public USDT = address(0xb03Ba6B311aaC34B06bdC97357E6f08BF2c12857);
    IRouter public pancakeRouter;

    constructor() {
        pancakeRouter = IRouter(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // replace with 0x10ED43C718714eb63d5aA57B78B54704E256024E while deploying to mainnet
        );
    }

    function getRate1(uint256 ip)
        internal
        view
        returns (uint256[] memory amounts)
    {
        address[] memory path = new address[](2);
        path[0] = address(address(0xB246610637676793BC2721C03e2b57478b922140));
        path[1] = pancakeRouter.WETH();
        return pancakeRouter.getAmountsOut(ip, path);
    }

    function getRate2(uint256 ip)
        internal
        view
        returns (uint256[] memory amounts)
    {
        address[] memory path = new address[](2);
        path[1] = address(USDT);
        path[0] = pancakeRouter.WETH();
        return pancakeRouter.getAmountsOut(ip, path);
    }

    function getPrice(uint256 toks) internal view returns (uint256) {
        uint256[] memory res1 = getRate1(toks);
        uint256[] memory res2 = getRate2(res1[1]);

        return (res2[1]);
    }
}