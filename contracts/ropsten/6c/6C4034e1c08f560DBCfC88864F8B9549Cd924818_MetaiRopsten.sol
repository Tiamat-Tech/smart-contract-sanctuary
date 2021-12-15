// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MetaiRopsten is ERC20 
{
	constructor() ERC20("MetaiRopsten", "MTIRPSN") 
	{
		uint256 initialSupply = 10000000*10**decimals();
        	_mint(_msgSender(), initialSupply);
	}
	function decimals() public view virtual override returns (uint8) 
	{
		return 18;
	}
}