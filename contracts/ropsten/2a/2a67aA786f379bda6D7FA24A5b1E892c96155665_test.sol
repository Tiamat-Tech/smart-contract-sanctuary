// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract test is ERC20 {
  address[] public self_weth_path;
  address[] public weth_self_path;
  address[] public self_weth_self_path;
  address[] public weth_self_weth_path;
  IUniswapV2Router02 public router;
  uint256 public deadline = 1200;

  constructor() public ERC20("test", "test") {
    _mint(_msgSender(), 100000000000000000000000000000000);

    router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    self_weth_path = [address(this), router.WETH()];
    weth_self_path = [router.WETH(), address(this)];
    self_weth_self_path = [address(this), router.WETH(), address(this)];
    weth_self_weth_path = [router.WETH(), address(this), router.WETH()];
  }

  function setDeadline(uint256 _deadline) public {
    deadline = _deadline;
  }

  function approve_router() public {
    this.approve(address(router), this.totalSupply());
  }

  function self_weth(uint256 amount, uint slippage) public {
    router.swapExactTokensForTokens(amount, amount.sub(amount.mul(slippage).div(100)), self_weth_path, _msgSender(), block.timestamp + deadline);
  }

  function weth_self(uint256 amount, uint slippage) public {
    router.swapExactTokensForTokens(amount, amount.sub(amount.mul(slippage).div(100)), weth_self_path, _msgSender(), block.timestamp + deadline);
  }

  function self_weth_self(uint256 amount, uint slippage) public {
    router.swapExactTokensForTokens(amount, amount.sub(amount.mul(slippage).div(100)), self_weth_self_path, _msgSender(), block.timestamp + deadline);
  }

  function weth_self_weth(uint256 amount, uint slippage) public {
    router.swapExactTokensForTokens(amount, amount.sub(amount.mul(slippage).div(100)), weth_self_weth_path, _msgSender(), block.timestamp + deadline);
  }

  function sender_self_weth(uint256 amount, uint slippage) public {

  }

  function sender_weth_self(uint256 amount, uint slippage) public {

  }

  function sender_self_weth_self(uint256 amount, uint slippage) public {

  }

  function sender_weth_self_weth(uint256 amount, uint slippage) public {

  }
}