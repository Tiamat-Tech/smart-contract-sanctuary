// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

// import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
//cimport "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
// TODO https://uniswap.org/docs/v2/smart-contract-integration/trading-from-a-smart-contract/

contract UniMfContract {

  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  IUniswapV2Router02 public uniswapRouter;

  modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
    _;
  }

  constructor() public {
    uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
  }


  // https://soliditydeveloper.com/uniswap2

  function convertEthToDai(address token, uint daiAmount, uint deadline) public payable {
    address[] memory path = new address[](2);
    path[0] = uniswapRouter.WETH();
    path[1] = token;

    uniswapRouter.swapETHForExactTokens.value(msg.value)(daiAmount, path, address(this), deadline);

    // refund leftover ETH to user
    msg.sender.call.value(address(this).balance)("");
  }

  function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline, uint val)
  ensure(deadline)
  external
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapETHForExactTokens.value(val)(amountOut, path, to, deadline);
  }

  function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline, uint val)
  ensure(deadline)
  external
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapExactETHForTokens.value(val)(amountOutMin, path, to, deadline);
  }

  function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
  ensure(deadline)
  external
  returns (uint[] memory amounts)
  {
    amounts = uniswapRouter.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
  }

  // important to receive ETH
  // TODO receive() payable external {}
}