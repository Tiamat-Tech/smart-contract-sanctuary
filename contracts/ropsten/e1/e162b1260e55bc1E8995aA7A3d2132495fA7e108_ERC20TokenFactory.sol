// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenERC20.sol";

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

contract ERC20TokenFactory {

  address public uniV2Router;

  address[] public tokens;
  mapping (address => mapping (address => bool)) public tiers;
  mapping (address => address) public lastTier;

	constructor(address _uniV2Router) {
    uniV2Router = _uniV2Router;
	}

  function createUniV2TokenETHPairWithTiers(
    address _owner,
    string memory name,
    string memory symbol,
    uint totalSupply,
    uint amountTokenDesired,
    address[] memory _tiers
  ) external payable returns (address token, address pair) {

    token = address(new TokenERC20(_owner, name, symbol, totalSupply, amountTokenDesired));

    TokenERC20(token).approve(uniV2Router, amountTokenDesired);

    IUniswapV2Router01(uniV2Router).addLiquidityETH{ value: msg.value }
      (token, amountTokenDesired, amountTokenDesired, msg.value, _owner, block.timestamp + 86400);

    pair = IUniswapV2Factory(IUniswapV2Router01(uniV2Router).factory())
      .getPair(token, IUniswapV2Router01(uniV2Router).WETH());

    TokenERC20(token).lock(true);

    for (uint i = 0; i < _tiers.length; i++) {
  	 tiers[token][_tiers[i]] = true;
		}
    lastTier[token] = _tiers[_tiers.length - 1];

    tokens.push(token);
  }

  function swapETHForTokens(address token) external payable {
    require(tiers[token][msg.sender] == true, "Only tier can call this once.");

    TokenERC20(token).lock(false);

    address[] memory path = new address[](2);
    path[0] = IUniswapV2Router01(uniV2Router).WETH();
    path[1] = token;

    IUniswapV2Router01(uniV2Router).swapExactETHForTokens{ value: msg.value }
      (0, path, msg.sender, block.timestamp + 86400);

    tiers[token][msg.sender] = false;

    if(msg.sender != lastTier[token]) {
      TokenERC20(token).lock(true);
    }

  }

}