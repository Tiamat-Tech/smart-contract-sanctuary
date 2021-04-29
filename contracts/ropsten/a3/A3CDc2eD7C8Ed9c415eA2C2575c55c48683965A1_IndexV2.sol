// SPDX-License-Identifier: Bityield
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import './bases/v2/IndexBase.sol';
import './interfaces/compound/v2/ceth.sol';

contract IndexV2 is IndexBaseV2, ERC20 {
  IUniswapV2Router02 private uniswapRouter;
  IUniswapV2Factory  private uniswapFactory;

  address internal cETH;

  /* ============ Events ================= */
  event EnterMarket(
	address indexed from_,
	uint amountDeposited_,
	uint cTokens_,
	uint currentBlock_
  );

  event ExitMarket(
	address indexed from_,
	uint amountWithdrawn_,
	uint cTokens_,
	uint currentBlock_
  );

  event ExchangeRate(
	string,
	uint256
  );

  event SwapInit(
	address indexed token_,
	uint amountIn_,
	uint[] amounts_
  );

  event SwapSuccess(
	address indexed token_,
	uint etherAmount_,
	uint[] amounts_
  );

  event SwapFailureBytes(
	address indexed token_,
	bytes err_
  );

  event SwapFailureString(
	address indexed token_,
	string err_
  );

  /* ============ Constructor ============ */
  constructor(
	string memory _name,
	string memory _symbol,
	address _cETH
  )
	public
	ERC20(_name, _symbol)
  {
	owner = msg.sender;
	cETH = _cETH;
  }

  function ping()
	public view returns(string memory)
  {
	return "pong";
  }

  // enterMarket; is the main entry point to this contract. It takes msg.value and splits
  // to the allocation ceilings in wei. Any funds not used are returned to the sender
  function enterMarket()
	external
	payable
  {
  	CEth cToken = CEth(cETH);

	// Amount of current exchange rate from cToken to underlying
	uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();
	emit ExchangeRate("exchangeRate; scaled up by 1e18:", exchangeRateMantissa);

	// Amount added to you supply balance this block
	uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
	emit ExchangeRate("exchangeRate; scaled up by 1e18:", supplyRateMantissa);

	uint256 sentEther = msg.value;
	require(sentEther > 0, "cannot send 0 ether");

	// Supply
	cToken.mint{value: sentEther, gas: 250000}();

	// Increment the balance
	balances[msg.sender][cETH] = balance(
		sentEther,
		0
  	);
  }

  function exitMarket()
	external
  {
	CEth cToken = CEth(cETH);

	uint256 amount = balances[msg.sender][cETH].ethAmount;
	require(amount > 0, "invalid ETH balance");

	uint256 redeemResult = cToken.redeem(amount);
	require(redeemResult > 0, "redeem error");
  }

  // receive; required to accept ether
  receive()
	external
	payable
  {}
}