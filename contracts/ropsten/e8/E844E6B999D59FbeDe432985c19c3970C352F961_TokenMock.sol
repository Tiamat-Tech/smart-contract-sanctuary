// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenMock is ERC20 {
	constructor(
		string memory name,
		string memory symbol,
		uint256 _amount
	) ERC20(name, symbol) {
		_mint(msg.sender, _amount);
	}

	function mint(address _to, uint256 _amount) public {
		_mint(_to, _amount);
	}
}