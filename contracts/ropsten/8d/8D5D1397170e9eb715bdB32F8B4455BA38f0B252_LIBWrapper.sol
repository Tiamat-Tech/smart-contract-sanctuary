// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./LIB.sol";

contract LIBWrapper {

	LIB public LibToken;

	constructor() {
		LibToken = LIB(0x9201d93D3A10Ce05Eb8226585b7022c2CCA5bF45);
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