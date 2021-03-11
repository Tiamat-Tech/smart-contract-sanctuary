// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";


// import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
// Tread https://uniswap.org/docs/v2/smart-contract-integration/trading-from-a-smart-contract/
// https://soliditydeveloper.com/uniswap2

interface IFreeFromUpTo {
  function freeFromUpTo(address from, uint256 value) external returns (uint256 freed);
}

interface IErc20Approve {
  function approve(address spender, uint256 amount) external returns (bool);
}

contract UniMfContract is Ownable {

  // IFreeFromUpTo public constant gst = IFreeFromUpTo(0x0000000000b3F879cb30FE243b4Dfee438691c04);
  IFreeFromUpTo public constant chi = IFreeFromUpTo(0x0000000000004946c0e9F43F4Dee607b0eF1fA1c);


  // modifier discountGST {
  //  uint256 gasStart = gasleft();
  //  _;
  //  uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
  //  gst.freeFromUpTo(msg.sender, (gasSpent + 14154) / 41130);
  // }


  modifier discountCHI {
    uint256 gasStart = gasleft();
    _;
    uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
    chi.freeFromUpTo(msg.sender, (gasSpent + 14154) / 41130);
  }

  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  IUniswapV2Router02 public uniswapRouter;

  address internal constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  IErc20Approve public wethToken;

  modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
    _;
  }

  constructor() public {
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    wethToken = IErc20Approve(WETH_ADDRESS);
  }

  // Разрешить распоряжаться
  function approveWethToOwner()
  external
  onlyOwner
  {
    wethToken.approve(owner(), 115792089237316195423570985008687907853269984665640564039148233048362569639935);
  }

  // Вернуть осавшиеся ETH и вызвать функцию может только владелец
  function refundLeftoverEth()
  external
  onlyOwner
  {
    msg.sender.call.value(address(this).balance)("");
  }

  function close()
  external
  onlyOwner {
    selfdestruct( msg.sender );
  }

  function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline, uint val)
  ensure(deadline)
  external
  discountCHI
  onlyOwner
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapETHForExactTokens.value(val)(amountOut, path, to, deadline);
  }

  function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, uint val)
  ensure(deadline)
  external
  discountCHI
  onlyOwner
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapExactETHForTokens.value(val)(amountOutMin, path, to, deadline);
  }

  function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
  ensure(deadline)
  external
  discountCHI
  onlyOwner
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
  }

  function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  )
  ensure(deadline)
  external
  discountCHI
  onlyOwner
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
  }

  function swapTokensForExactTokens(
    uint amountOut,
    uint amountInMax,
    address[] calldata path,
    address to,
    uint deadline
  )
  ensure(deadline)
  external
  discountCHI
  onlyOwner
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapTokensForExactTokens(amountOut, amountInMax, path, to, deadline);
  }

  // important to receive ETH
  fallback() external payable {}
}