pragma solidity ^0.5.0;

// SPDX-License-Identifier: MIT

import "ERC20.sol";
import "ERC20Detailed.sol";
import "ERC20Mintable.sol";

/**
    @title HUSKY
    @notice Based on the ERC-20 token standard as defined at
            https://eips.ethereum.org/EIPS/eip-20
 */
contract HuskyToken is ERC20, ERC20Detailed, ERC20Mintable {
	constructor(
		string memory name,
		string memory symbol,
		uint initial_supply
	)
	ERC20Detailed(name, symbol, 18)
	public {

	}
}