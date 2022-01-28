// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../../utils/Context.sol";
import "./ERC20.sol";

contract ERC20Mintable is ERC20 {
	constructor() public ERC20("RollTestToken", "RTT", 8) {}

	function mint(address account, uint256 amount) public {
		_mint(account, amount);
	}

	function mintAndGet(uint256 amount) public {
		_mint(msg.sender, amount);
	}

	function burn(address account, uint256 amount) public {
		_burn(account, amount);
	}
}