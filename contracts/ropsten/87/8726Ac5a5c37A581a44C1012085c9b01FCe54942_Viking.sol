pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "hardhat/console.sol";

contract Viking is ERC721URIStorage {
	uint256 public tokenCounter;

	constructor() ERC721("Viking", "VKNG") {
		tokenCounter = 0;
	}

	function createTestNFT(string memory tokenURI) public returns (uint256) {
		uint256 newItemId = tokenCounter;

		_safeMint(msg.sender, newItemId);
		_setTokenURI(newItemId, tokenURI);
		tokenCounter = tokenCounter + 1;
		return newItemId;
	}
}