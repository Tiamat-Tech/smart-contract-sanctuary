// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./LIB.sol";

contract LIBWrapper {

	LIB public LibToken;

	address tokenAddress = 0xd0f795454e19554dd3135715834003ed21190998;

	constructor() {
		// set the address of the deployed token
		LibToken = LIB(tokenAddress);
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