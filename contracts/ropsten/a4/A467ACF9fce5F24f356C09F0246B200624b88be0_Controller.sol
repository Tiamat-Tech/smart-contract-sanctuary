// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./UniswapV2.sol";
import "./Farm.sol";

contract Controller is Initializable {
    using SafeMath for uint256;

    UniswapV2 private uniswap;
    uint256 public timeLock;
    address public owner;

    address public constant TOKEN = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address public constant FARMCONTRACT =
        0x0895196562C7868C5Be92459FaE7f877ED450452;
    address public constant CAKE = 0x0895196562C7868C5Be92459FaE7f877ED450452;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function initialize() public initializer {
        owner = msg.sender;
        uniswap = UniswapV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        timeLock = 0;
    }

    function getBalance() public view returns (uint256) {
        return IERC20(TOKEN).balanceOf(address(this));
    }

    function initApproval(address token, address spender) public onlyOwner {
        IERC20(token).approve(spender, uint256(~0));
    }

    function TokentoCoin(address customtoken) public onlyOwner {
        uint256 customtokenBal = IERC20(customtoken).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = customtoken;
        path[1] = uniswap.WETH();

        uint256[] memory amountOutMin =
            uniswap.getAmountsOut(customtokenBal, path);

        uint256 outvar = amountOutMin[1];

        uniswap.swapExactTokensForTokens(
            customtokenBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function pushin() public {
        uint256 wethBal = IERC20(uniswap.WETH()).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = uniswap.WETH();
        path[1] = TOKEN;

        uint256[] memory amountOutMin = uniswap.getAmountsOut(wethBal, path);
        uint256 outvar = amountOutMin[1];

        uniswap.swapExactTokensForTokens(
            wethBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function pushincustom(address customtoken) internal {
        uint256 wethBal = IERC20(customtoken).balanceOf(address(this));

        address[] memory path = new address[](3);
        path[0] = customtoken;
        path[1] = uniswap.WETH();
        path[2] = TOKEN;

        uint256[] memory amountOutMin = uniswap.getAmountsOut(wethBal, path);
        uint256 outvar = amountOutMin[2];

        uniswap.swapExactTokensForTokens(
            wethBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function addLP() internal {
        uint256 tokenBal = IERC20(TOKEN).balanceOf(address(this));
        uint256 halfBal = tokenBal.div(2);

        address[] memory path = new address[](2);
        path[0] = TOKEN;
        path[1] = uniswap.WETH();

        uint256[] memory amountOutMin = uniswap.getAmountsOut(halfBal, path);
        uint256 outvar = amountOutMin[1];

        uniswap.swapExactTokensForTokens(
            halfBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );

        uint256 tokenBalance = IERC20(TOKEN).balanceOf(address(this));
        uint256 wethBalance = IERC20(uniswap.WETH()).balanceOf(address(this));

        uniswap.addLiquidity(
            TOKEN,
            uniswap.WETH(),
            tokenBalance,
            wethBalance,
            0,
            0,
            address(this),
            block.timestamp + 100
        );
    }

}