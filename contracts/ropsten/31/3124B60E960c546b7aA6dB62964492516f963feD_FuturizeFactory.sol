// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8;

import './FuturizeUV3Pair.sol';
import './interfaces/FuturizeInterfaces.sol';

contract FuturizeFactory {
	IExternalRouter router;

	mapping(address => mapping(address => address)) public getPair;
	address[] public allPairs;

	event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

	constructor(IExternalRouter _router) {
		router = _router;
	}

	function allPairsLength() external view returns (uint256) {
		return allPairs.length;
	}

	function createPair(address tokenA, address tokenB) external returns (address pair) {
		require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
		(address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
		require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
		require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
		bytes memory bytecode = type(FuturizeUV3Pair).creationCode;
		bytes32 salt = keccak256(abi.encodePacked(token0, token1));
		assembly {
			pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
		}
		IFuturizePair(pair).initialize(token0, token1, router);
		getPair[token0][token1] = pair;
		getPair[token1][token0] = pair; // populate mapping in the reverse direction
		allPairs.push(pair);
		emit PairCreated(token0, token1, pair, allPairs.length);
	}
}