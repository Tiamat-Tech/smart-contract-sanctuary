// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Evmoon is ERC20 {
	constructor()
	ERC20("Evmoon", "EVM") {
		_mint(msg.sender, 100000 * 10 ** 18);
	}
}