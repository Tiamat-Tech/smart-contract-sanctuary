pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TacticalTangrams is ERC721URIStorage {
	// Mint limits
	uint8 constant maxMintPerAddress = 7;
	uint56 constant mintPrice = 7 * 1e16;
	uint16 constant maxMints = 7777;
	uint256 public mintCounter;

	mapping (address => uint256) public mints;

	// Team share
	address[4] public _payees = [
		0x295cf92fAaE3cf809155850bfCC5cBc742A72b27,
		0x13e6A2dF42E00883b059f852Cb1d0C78Ebe3CBcE,
		0x9ccd31CAE8B047DdEfA522C347886d51fACCEE69,
		0x0C3483e3B355986D6Bb76E3CEbBC8dD8EC20779C
	];

	uint256[4] public _mintShares = [
		3150 * 1e13,
		2100 * 1e13,
		 875 * 1e13,
		 875 * 1e13
	];

	uint256[4] public _mintSharesPaid;

	constructor() ERC721 ("Tactical Tangrams", "TACT") {
		mintCounter = 0;
	}

	function release(address account) public {
	 	for (uint8 i = 0; i < 4; i++) {
	 		if (_payees[i] == account) {
	 			uint256 payment;
	 			if (_mintSharesPaid[i] < mintCounter) {
	 				payment = _mintShares[i] * (mintCounter - _mintSharesPaid[i]);
	 				_mintSharesPaid[i] = mintCounter;
	 			}


	 			if (payment > 0) {
	 				(bool sent, ) = account.call{value: payment}("");
	 				require(sent, "Can't send payment");
	 			}
	 			break;
	 		}
	 	}
	}

	function mint() public payable {
		require(mintCounter < maxMints, "No more mints allowed");
		uint8 numberOfTansToMint = uint8(msg.value / mintPrice);
		require(mints[msg.sender] + numberOfTansToMint <= maxMintPerAddress, "Max 7 mints per address");
		require(mintCounter + numberOfTansToMint <= maxMints, "Max 7777 mints");

		mints[msg.sender] += numberOfTansToMint;
		mintCounter += numberOfTansToMint;

		if (mintCounter == maxMints) {
			// 
		}
	}
}