// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";


contract UniswapTest {
    IUniswapV2Router02 internal constant _router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    event Swaped(address, uint256, uint256);

    function TransferIn(address token) external payable {
        // IUniswapV2Router02 Uniswap = IUniswapV2Router02(uniswap);
        address[] memory path = new address[](2);
		path[0] = _router.WETH();
		path[1] = token;
        uint[] memory amounts = _router.swapExactETHForTokens{ value: msg.value }(0, path, address(this), block.timestamp + 1000);
        emit Swaped(token, amounts[0], amounts[1]);
    }

    function TransferOut(address token, uint amountIn) external {
        // IUniswapV2Router02 Uniswap = IUniswapV2Router02(uniswap);
        address[] memory path = new address[](2);
		path[0] = token;
		path[1] = _router.WETH();
        uint[] memory amounts = _router.swapExactTokensForETH(amountIn, 0, path, payable(msg.sender), block.timestamp + 1000);
        emit Swaped(token, amounts[0], amounts[1]);
        // msg.sender.transfer(address(this).balance);
    }

    function withdraw() public {
        uint amount = address(this).balance;
        address payable to = payable(msg.sender);
        (bool success,) = to.call{value: amount}("");
        require(success, "Failed to send Ether");
    }
    
}