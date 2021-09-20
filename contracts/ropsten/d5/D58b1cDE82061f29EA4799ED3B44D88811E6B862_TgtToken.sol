pragma solidity 0.7.6;

import "./ERC20Standard.sol";

contract TgtToken is ERC20Standard {
	constructor(uint total) public {
		totalSupply = total;
		name="TigrToken";
		decimals = 4;
		symbol = "TGT";
		version = "1.0";
		balances[msg.sender]=totalSupply;
	}
}