// SPDX-License-Identifier: GPL-2.0

pragma solidity ^0.8.0;

import "./interface/IUniswapV2Router02.sol";
import "./lib/IERC20.sol";

contract TestSwap {
     address token0;
     address token1;
     address to;
    constructor(address _token0, address _token1,address _to){
       token0=_token0;
        token1=_token1;
        to=_to;
    }
//    address token0 = 0x74b095e48eb8ba11c79b5e400b5f552a32ea82d4;
//    address token1 = 0xadc8cc224b13805418abc245f08f08e9bd1f686e;
    function addLp() external{
        IERC20(token0).approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,1000000000000000000);
        IERC20(token1).approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,1000000000000000000);
    IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D).addLiquidity(token0,
        token1,
        1000000000000000000,
        1000000000000000000,
        1000000,
        1000000,
        to,
        2632590264
    );
    }
}