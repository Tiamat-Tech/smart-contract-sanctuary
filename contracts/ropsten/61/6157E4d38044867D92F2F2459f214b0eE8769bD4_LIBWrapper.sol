// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./LIB.sol";

contract LIBWrapper {

	LIB public LibToken;

	address tokenAddress = 0x0e535322BFccab6B70a17c002fa10CF83c6A54Ce;

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

	function wrapWithSignature(bytes32 hashedMessage, uint8 v, bytes32 r, bytes32 s, address receiver) public payable {
		require(msg.value > 0, "We need to wrap at least 1 wei");
		require(recoverSigner(hashedMessage, v,r,s) == receiver, "Receiver did not sign the message");
		LibToken.mint(receiver, msg.value);
		emit LogETHWrapped(receiver, msg.value);
	}

	function recoverSigner(bytes32 hashedMessage, uint8 v, bytes32 r, bytes32 s) internal returns (address) {
		bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hashedMessage));
		return ecrecover(messageDigest, v, r, s);
	}

}