// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";


// deployed to 0x999261cE9d734531F1cf999cf7325263B7E1aA30

contract LIB is ERC20PresetMinterPauser {

	constructor() ERC20PresetMinterPauser("LibToken", "LIB") {

	}
	
	function getMinterRole() public returns (bytes32) {
		return MINTER_ROLE;
	}

}