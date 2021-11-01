// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUniswapV2Router {
  function getAmountsOut(uint256 amountIn, address[] memory path)
    external
    view
    returns (uint256[] memory amounts);
  
  function swapExactTokensForTokens(
  
    uint256 amountIn,

    uint256 amountOutMin,

    address[] calldata path,

    address to,

    uint256 deadline
  ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;
}

interface IUniswapV2Factory {
  function getPair(address token0, address token1) external returns (address);
}


contract TTSwap is ERC20{
    constructor() ERC20("TTSIDA", "TTSI") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
    
    //address of the uniswap v2 router
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    function swap(address tokenAddressIn, address tokenAddressOut, uint256 amount, address _to) external {
      
    IERC20(tokenAddressIn).transferFrom(msg.sender, address(this), amount);
    
    IERC20(tokenAddressIn).approve(UNISWAP_V2_ROUTER, amount);

    address[] memory path;
    if (tokenAddressIn == WETH || tokenAddressOut == WETH) {
      path = new address[](2);
      path[0] = tokenAddressIn;
      path[1] = tokenAddressOut;
    } else {
      path = new address[](3);
      path[0] = tokenAddressIn;
      path[1] = WETH;
      path[2] = tokenAddressOut;
    }

        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(amount, 0, path, _to, block.timestamp);
    }
}