pragma solidity =0.6.6;

import './UniswapV2Library.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IERC20.sol';

contract FlashLoaner {
  address immutable factory;
  uint constant deadline = 1 hours;

  IUniswapV2Router02 immutable uniRouter;
  IUniswapV2Router02 immutable sushiRouter;

  event SenderDetails(
    address indexed funSender_,
    address indexed msgSender_,
    address token0_,
    address token1_,
    address pair_
  );

  constructor(address _factory, address _uniRouter, address _sushiRouter) public {
    factory = _factory;

    sushiRouter = IUniswapV2Router02(_sushiRouter);
    uniRouter   = IUniswapV2Router02(_uniRouter);
  }

  function uniswapV2Call(address _sender, uint _amount0, uint _amount1, bytes calldata _data) external {
      address[] memory path = new address[](2);
      uint amountToken = _amount0 == 0 ? _amount1 : _amount0;

      // The sender is essentially the IUniswapV2Pair
      address token0 = IUniswapV2Pair(msg.sender).token0();
      address token1 = IUniswapV2Pair(msg.sender).token1();

      address pairF = UniswapV2Library.pairFor(factory, token0, token1);

      emit SenderDetails(
        _sender,
        msg.sender,
        token0,
        token1,
        pairF
      );

      require(msg.sender == pairF, "Unauthorized");
      require(_amount0 == 0 || _amount1 == 0);

      path[0] = _amount0 == 0 ? token1 : token0;
      path[1] = _amount0 == 0 ? token0 : token1;

      IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);

      token.approve(address(sushiRouter), amountToken);

      // no need for require() check, if amount required is not sent sushiRouter will revert
      uint amountRequired = UniswapV2Library.getAmountsIn(factory, amountToken, path)[0];
      uint amountReceived = sushiRouter.swapExactTokensForTokens(amountToken, amountRequired, path, msg.sender, deadline)[1];

      // YEAHH PROFIT
      token.transfer(_sender, amountReceived - amountRequired);
  }
}