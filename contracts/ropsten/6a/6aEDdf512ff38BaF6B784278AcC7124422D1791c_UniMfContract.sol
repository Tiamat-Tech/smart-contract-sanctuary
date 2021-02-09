// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

// import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
//cimport "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
// TODO https://uniswap.org/docs/v2/smart-contract-integration/trading-from-a-smart-contract/

contract UniMfContract {

  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  IUniswapV2Router02 public uniswapRouter;


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


  // important to receive ETH
  // TODO receive() payable external {}
}