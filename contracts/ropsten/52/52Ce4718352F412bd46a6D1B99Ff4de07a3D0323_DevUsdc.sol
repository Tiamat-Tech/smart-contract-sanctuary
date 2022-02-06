// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract DevUsdc is ERC20 
{
	constructor() ERC20("Dev USDC2", "DEVUSDC2") 
	{
		uint256 initialSupply = 10000000000000*10**decimals();
        	_mint(_msgSender(), initialSupply);
	}
	function decimals() public view virtual override returns (uint8) 
	{
		return 6;
	}
}