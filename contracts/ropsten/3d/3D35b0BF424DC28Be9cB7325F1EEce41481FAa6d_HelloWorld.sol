//SPDX-License-Identifier: Unlicense

// Metamask: 0x5947C3F6Fd59D8eb5EacB44d2d18210ebc4f2592
// Deployement 0x544d8AA1Ba72E74DDfF1a1187FC74dFef3E86032
//pragma solidity ^0.8.0;
pragma solidity ^0.7.3;

import "hardhat/console.sol";

contract HelloWorld {
    
	event UpdateMessages(string oldStr, string newStr);
	
	string public message;
	
	constructor(string memory initMessage) {
		message = initMessage;
	}
	
	function update(string memory newMessage) public {
		string memory oldMsg = message;
		message = newMessage;
		emit UpdateMessages(oldMsg, newMessage);
	}
}