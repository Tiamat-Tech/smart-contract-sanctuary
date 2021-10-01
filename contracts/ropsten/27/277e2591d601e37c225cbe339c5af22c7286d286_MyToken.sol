// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./openzeppelin/token/ERC20/ERC20Upgradeable.sol";

contract MyToken is ERC20Upgradeable {
	function initialize(string memory _name, string memory _symbol)
		public
		initializer
	{
		__ERC20_init(_name, _symbol);
		_mint(msg.sender, 32000000000000000000000);
	}
}