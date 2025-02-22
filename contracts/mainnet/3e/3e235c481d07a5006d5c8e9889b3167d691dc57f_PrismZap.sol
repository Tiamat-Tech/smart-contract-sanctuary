// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.8;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

contract PrismZap is ReentrancyGuard {
	using SafeMath for uint256;

	uint256 immutable deadline = 0xf000000000000000000000000000000000000000000000000000000000000000;
	IUniswapV2Router02 immutable uniswap = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
	address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
	address immutable DEF = 0x3Aa5f749d4a6BCf67daC1091Ceb69d1F5D86fA53;

	constructor() public {
		IERC20(0x3Aa5f749d4a6BCf67daC1091Ceb69d1F5D86fA53).approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, uint256(-1));
	}

	function _uniswapETHForToken(uint256 _amount) private returns (uint256[] memory amounts) {
		address[] memory path = new address[](2);
		path[0] = WETH;
		path[1] = DEF;
		amounts = uniswap.swapExactETHForTokens{ value: _amount }(0, path, address(this), deadline); // amounts[0] = WETH, amounts[1] = DEF
	}

	function zap() external payable nonReentrant() {
		uint256 ethAmount = msg.value;
		uint256 defBalanceBefore = IERC20(DEF).balanceOf(address(this));
		_uniswapETHForToken(ethAmount.div(2)); // amounts[0] = WETH, amounts[1] = DEF
		uint256 defBalanceAfter = IERC20(DEF).balanceOf(address(this));
		uint256 defAmount = defBalanceAfter.sub(defBalanceBefore);
		(uint256 amountToken, uint256 amountETH, ) = uniswap.addLiquidityETH{ value: ethAmount.div(2) }(DEF, defAmount, 0, 0, msg.sender, deadline);
		if (ethAmount.div(2) > amountETH) {
			uint256 returnETHamount = ethAmount.div(2).sub(amountETH);
			msg.sender.call{ value: returnETHamount }('');
		} else if (defAmount > amountToken) {
			uint256 returnDEFamount = defAmount.sub(amountToken);
			IERC20(DEF).transfer(msg.sender, returnDEFamount);
		}
	}

	receive() external payable {}
}