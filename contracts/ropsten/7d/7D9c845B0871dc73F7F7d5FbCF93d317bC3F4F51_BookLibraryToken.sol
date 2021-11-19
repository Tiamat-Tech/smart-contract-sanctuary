// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BookLibraryToken is ERC20 {
	constructor()
	  ERC20("BookLibraryToken", "BLT")
	{
	}

	function mint(
		address to,
		uint256 amount
	) public
	  virtual
	{
		_mint(to, amount);
	}

	function burn(
		address account,
		uint256 amount
	) public 
	  virtual
	{
		_burn(account, amount);
	}
}