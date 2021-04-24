// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";


contract UniswapTest {
    event Swaped(address, uint256, uint256);

    function TransferIn(address uniswap, address token) external payable {
        IUniswapV2Router02 Uniswap = IUniswapV2Router02(uniswap);
        address[] memory path = new address[](2);
		path[0] = Uniswap.WETH();
		path[1] = token;
        uint[] memory amounts = Uniswap.swapETHForExactTokens(0, path, address(this), block.timestamp + 1000);
        emit Swaped(token, amounts[0], amounts[1]);
    }

    function TransferOut(address uniswap, address token, uint amountIn) external {
        IUniswapV2Router02 Uniswap = IUniswapV2Router02(uniswap);
        address[] memory path = new address[](2);
		path[0] = token;
		path[1] = Uniswap.WETH();
        uint[] memory amounts = Uniswap.swapExactTokensForETH(amountIn, 0, path, msg.sender, block.timestamp + 1000);
        emit Swaped(token, amounts[0], amounts[1]);
    }
}