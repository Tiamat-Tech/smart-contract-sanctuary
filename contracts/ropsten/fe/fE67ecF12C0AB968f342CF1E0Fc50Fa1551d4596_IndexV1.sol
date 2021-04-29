// SPDX-License-Identifier: Bityield
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import './lib/AddressArrayUtils.sol';

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract IndexBase {
	using Address for address;
	using AddressArrayUtils for address[];
	using SafeMath for uint;
	using SafeMath for uint256;
	
	uint256 internal constant CONVERSION_RATE = 10; // 10 tokens per Ether
	
	uint256 internal constant ETHER_BASE = 1000000000000000000;
	address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
	address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
	
	address internal owner;
	
	// balance; used to hold a more efficient set of balances per investor address
	// and token address
	struct balance {
		uint ethAmount;
		uint tokAmount;
	}
	
	// assetAddresses; this is an array of the tokens that will be held in this fund 
	// A valid Uniswap pair must be present on the execution network to provide a swap
	address[] internal assetAddresses;
	
	// assetLimits; this maps the asset(a token's address) => to it's funding allocation maximum
	// example: {0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984 => 100000000000000000}
	mapping (address => uint256) internal assetLimits;
	
	// balances; one level deeper to hold the balance of a specific token per an address
	// example: {0xInvestorAddress: {0xTokenAddress => (uint256 balance)}
	mapping (address => mapping (address => balance)) internal balances;
}