// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract BLSToken is ERC20 {
	
	constructor() public ERC20("BlocTech", "BLS") {
		_mint(msg.sender, 18);
	}
}