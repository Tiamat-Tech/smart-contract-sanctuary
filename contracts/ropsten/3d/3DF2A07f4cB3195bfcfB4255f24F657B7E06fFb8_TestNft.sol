pragma solidity ^0.7.5;
pragma abicoder v2;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";

contract TestNft is ERC721Burnable {

	using Counters for Counters.Counter;

	Counters.Counter private _tokenIdTracker;                   // Token id tracker.

	constructor(string memory name, string memory symbol) ERC721(name, symbol) {
	}

	function mintNft(string memory ImageUri) public returns (uint256 newId) 
	{
		_tokenIdTracker.increment();
		newId = _tokenIdTracker.current();
		_safeMint(msg.sender, newId);
		_setTokenURI(newId, ImageUri);
	}
}