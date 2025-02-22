// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
import "../utils/DAOContract.sol";
import "../Interfaces.sol";
import "./SimpleStaking.sol";

library UniswapV2SwapHelper {
	function getRouter(SimpleStaking staking) public view returns (Uniswap) {
		return Uniswap(staking.nameService().getAddress("UNISWAP_ROUTER"));
	}

	/**
	 *@dev Helper to calculate percentage out of token liquidity in pool that is safe to exchange against sandwich attack.
	 * also checks if token->eth has better safe limit, so perhaps doing tokenA->eth->tokenB is better than tokenA->tokenB
	 * in that case it could be that eth->tokenB can be attacked because we dont know if eth received for tokenA->eth is less than _maxPercentage of the liquidity in
	 * eth->tokenB. In our use case it is always eth->dai so either it will be safe or very minimal
	 *@param _inToken address of token we are swapping
	 *@param _outToken address of swap result token
	 *@param _inTokenAmount amount of in token required to swap
	 */
	function maxSafeTokenAmount(
		SimpleStaking staking,
		address _inToken,
		address _outToken,
		uint256 _inTokenAmount
	) public view returns (uint256 safeAmount) {
		Uniswap uniswap = getRouter(staking);
		address wETH = uniswap.WETH();
		_inToken = _inToken == address(0x0) ? wETH : _inToken;
		_outToken = _outToken == address(0x0) ? wETH : _outToken;
		UniswapPair pair = UniswapPair(
			UniswapFactory(uniswap.factory()).getPair(_inToken, _outToken)
		);
		(uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
		uint112 reserve = reserve0;
		if (_inToken == pair.token1()) {
			reserve = reserve1;
		}

		safeAmount = (reserve * staking.maxLiquidityPercentageSwap()) / 100000;

		return safeAmount < _inTokenAmount ? safeAmount : _inTokenAmount;
	}

	/**
	@dev Helper to swap tokens in the Uniswap
	*@param _path the buy path
	*@param _tokenAmount token amount to swap
	*@param _minTokenReturn minimum token amount to get in swap transaction
	*@param _receiver receiver of tokens after swap transaction
    *
	 */
	function swap(
		SimpleStaking staking,
		address[] memory _path,
		uint256 _tokenAmount,
		uint256 _minTokenReturn,
		address _receiver
	) internal returns (uint256 swapResult) {
		Uniswap uniswapContract = getRouter(staking);
		uint256[] memory result;

		if (_path[0] == address(0x0)) {
			_path[0] = uniswapContract.WETH();
			result = uniswapContract.swapExactETHForTokens{
				value: _tokenAmount
			}(_minTokenReturn, _path, _receiver, block.timestamp);
		} else if (_path[_path.length - 1] == address(0x0)) {
			_path[_path.length - 1] = uniswapContract.WETH();
			result = uniswapContract.swapExactTokensForETH(
				_tokenAmount,
				_minTokenReturn,
				_path,
				_receiver,
				block.timestamp
			);
		} else {
			result = uniswapContract.swapExactTokensForTokens(
				_tokenAmount,
				_minTokenReturn,
				_path,
				_receiver,
				block.timestamp
			);
		}
		return result[result.length - 1];
	}
}