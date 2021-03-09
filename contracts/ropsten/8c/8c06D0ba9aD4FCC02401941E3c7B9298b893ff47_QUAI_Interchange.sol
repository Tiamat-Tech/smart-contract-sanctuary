// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.7.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract QUAI_Interchange is Ownable {
    using SafeMath for uint256;

    address public constant uniswapV2router =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 router = IUniswapV2Router02(uniswapV2router);

    //gets expected amount of ETH from input amount of ERC20 token
    function getExpectedEth(address tokenAddress, uint256 amountIn)
        public
        view
        returns (uint256)
    {
        address[] memory _path = new address[](2);
        _path[0] = tokenAddress;
        _path[1] = router.WETH();
        uint256[] memory _amts = router.getAmountsOut(amountIn, _path);
        return _amts[1];
    }

    function swapERC20ForETH(address tokenAddress, uint256 amountIn) external {
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >=
                amountIn,
            "token approval is insufficent for purchase"
        );
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenAddress;
        path[1] = router.WETH();

        uint256 deadline = (block.timestamp + 300); // 5 min window for transaction to be confirmed, otherwise it will revert

        router.swapExactTokensForETH(
            amountIn,
            uint256(0),
            path,
            address(this),
            deadline
        );
    }
}