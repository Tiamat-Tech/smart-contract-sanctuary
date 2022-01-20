pragma solidity >=0.8.0;

import {IUniswapV2Router02} from "./IUniswapRouter.sol";
import {IERC20} from "./ierc20.sol";

contract TokenSwap {
    IUniswapV2Router02 uniswapRouter;
    IUniswapV2Router02 sushiswapRouter;

    constructor(address _uniswapAddress, address _sushiswapAddress) {
        uniswapRouter = IUniswapV2Router02(_uniswapAddress);
        sushiswapRouter = IUniswapV2Router02(_sushiswapAddress);
    }

    function arbitrage(address _token0, address _token1, uint256 _amount) external {
        IERC20(_token0).transferFrom(msg.sender, address(this), _amount);
        IERC20(_token0).approve(address(uniswapRouter), _amount);

        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;

        uint256[] memory output = uniswapRouter.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp+15);

        IERC20(_token1).approve(address(sushiswapRouter), output[1]);

        path[0] = _token1;
        path[1] = _token0;

        sushiswapRouter.swapExactTokensForTokens(output[1], 0, path, msg.sender, block.timestamp+15);

    }
}