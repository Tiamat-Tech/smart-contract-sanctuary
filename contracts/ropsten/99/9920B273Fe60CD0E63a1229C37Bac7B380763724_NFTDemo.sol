// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract NFTDemo is ERC721URIStorage, Ownable {
	uint256 private _tokenId;

	constructor (string memory name, string memory symbol) ERC721(name, symbol) Ownable() {

	}

	function mint(address to) public onlyOwner {
		_tokenId ++;
		_safeMint(to, _tokenId);
	}
}