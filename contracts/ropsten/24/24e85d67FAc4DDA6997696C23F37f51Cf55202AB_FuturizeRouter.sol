// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8;

import './libraries/TransferHelper.sol';
import './FuturizeUV3Pair.sol';
import './FuturizeFactory.sol';
import './interfaces/IFuturizeRouter.sol';
import './libraries/UniswapV2Library.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract FuturizeRouter is IFuturizeRouter {
	address public immutable override factory;
	address public immutable override WETH;

	modifier ensure(uint256 deadline) {
		require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
		_;
	}

	constructor(address _factory, address _WETH) {
		factory = _factory;
		WETH = _WETH;
	}

	receive() external payable {
		assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
	}

	function openPos(
		address tokenA,
		address tokenB,
		uint256 collateral0,
		uint256 collateral1,
		address to,
		uint256 minReceived
	) public {
		address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
		collateral0 > 0
			? TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, collateral0)
			: TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, collateral1);
		FuturizeUV3Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB)).open(
			collateral0,
			collateral1,
			to,
			minReceived
		);
	}

	// **** LIQUIDATE POSITIONS AND REMOVE LIQUIDITY ****
	function liquidateAndBurn(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256[] calldata positionIds,
		uint256 deadline,
		uint256[2] calldata minReceived
	) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
		address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
		IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair

		(amountA, amountB) = FuturizeUV3Pair(pair).liquidateAndBurn(to, positionIds, minReceived[0], minReceived[1]);

		(address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
		(amountA, amountB) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);
		require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
		require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
	}

	function liquidatePositions(
		address tokenA,
		address tokenB,
		uint256[] calldata _positionIds,
		uint256[2] calldata minReceived
	) public {
		address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
		FuturizeUV3Pair(pair).liquidate(_positionIds, minReceived[0], minReceived[1]);
	}

	// **** ADD LIQUIDITY ****
	function _addLiquidity(
		address tokenA,
		address tokenB,
		uint256 amountADesired,
		uint256 amountBDesired,
		uint256 amountAMin,
		uint256 amountBMin
	) internal virtual returns (uint256 amountA, uint256 amountB) {
		// create the pair if it doesn't exist yet
		if (FuturizeFactory(factory).getPair(tokenA, tokenB) == address(0)) {
			FuturizeFactory(factory).createPair(tokenA, tokenB);
		}
		(uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
		if (reserveA == 0 && reserveB == 0) {
			(amountA, amountB) = (amountADesired, amountBDesired);
		} else {
			uint256 amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
			if (amountBOptimal <= amountBDesired) {
				require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
				(amountA, amountB) = (amountADesired, amountBOptimal);
			} else {
				uint256 amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
				assert(amountAOptimal <= amountADesired);
				require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
				(amountA, amountB) = (amountAOptimal, amountBDesired);
			}
		}
	}

	function addLiquidity(
		address tokenA,
		address tokenB,
		uint256 amountADesired,
		uint256 amountBDesired,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	)
		external
		virtual
		override
		ensure(deadline)
		returns (
			uint256 amountA,
			uint256 amountB,
			uint256 liquidity
		)
	{
		(amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
		address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
		TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
		TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
		liquidity = IUniswapV2Pair(pair).mint(to);
	}

	function addLiquidityETH(
		address token,
		uint256 amountTokenDesired,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	)
		external
		payable
		virtual
		override
		ensure(deadline)
		returns (
			uint256 amountToken,
			uint256 amountETH,
			uint256 liquidity
		)
	{
		(amountToken, amountETH) = _addLiquidity(
			token,
			WETH,
			amountTokenDesired,
			msg.value,
			amountTokenMin,
			amountETHMin
		);
		address pair = UniswapV2Library.pairFor(factory, token, WETH);
		TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
		IWETH(WETH).deposit{value: amountETH}();
		assert(IWETH(WETH).transfer(pair, amountETH));
		liquidity = IUniswapV2Pair(pair).mint(to);
		// refund dust eth, if any
		if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
	}

	// **** REMOVE LIQUIDITY ****
	function removeLiquidity(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
		address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
		IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
		(uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
		(address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
		(amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
		require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
		require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
	}

	function removeLiquidityETH(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
		(amountToken, amountETH) = removeLiquidity(
			token,
			WETH,
			liquidity,
			amountTokenMin,
			amountETHMin,
			address(this),
			deadline
		);
		TransferHelper.safeTransfer(token, to, amountToken);
		IWETH(WETH).withdraw(amountETH);
		TransferHelper.safeTransferETH(to, amountETH);
	}

	function removeLiquidityWithPermit(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external virtual override returns (uint256 amountA, uint256 amountB) {
		address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
		uint256 value = approveMax ? type(uint256).max : liquidity;
		IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
		(amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
	}

	function removeLiquidityETHWithPermit(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external virtual override returns (uint256 amountToken, uint256 amountETH) {
		address pair = UniswapV2Library.pairFor(factory, token, WETH);
		uint256 value = approveMax ? type(uint256).max : liquidity;
		IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
		(amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
	}

	// **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
	function removeLiquidityETHSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) public virtual override ensure(deadline) returns (uint256 amountETH) {
		(, amountETH) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline);
		TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
		IWETH(WETH).withdraw(amountETH);
		TransferHelper.safeTransferETH(to, amountETH);
	}

	function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external virtual override returns (uint256 amountETH) {
		address pair = UniswapV2Library.pairFor(factory, token, WETH);
		uint256 value = approveMax ? type(uint256).max : liquidity;
		IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
		amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
			token,
			liquidity,
			amountTokenMin,
			amountETHMin,
			to,
			deadline
		);
	}
}