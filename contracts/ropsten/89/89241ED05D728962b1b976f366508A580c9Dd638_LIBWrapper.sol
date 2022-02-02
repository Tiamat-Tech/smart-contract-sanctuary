// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./LIB.sol";

// deployed to	0x4BBaec9709B2064CFd2CDA6E9d8F1972A0944bEC

contract LIBWrapper {

	LIB public LibToken;

	constructor() {
		LibToken = LIB(address(0x999261cE9d734531F1cf999cf7325263B7E1aA30));
	}

    event LogETHWrapped(address sender, uint256 amount);
    event LogETHUnwrapped(address sender, uint256 amount);

    receive() external payable {
		wrap();
	} 

	function wrap() public payable {
		require(msg.value > 0, "We need to wrap at least 1 wei");
		LibToken.mint(msg.sender, msg.value);
		emit LogETHWrapped(msg.sender, msg.value);
	}

	function unwrap(uint value) public {
		require(value > 0, "We need to unwrap at least 1 wei");
		LibToken.transferFrom(msg.sender, address(this), value);
		LibToken.burn(value);
		msg.sender.transfer(value);
		emit LogETHUnwrapped(msg.sender, value);
	}

}