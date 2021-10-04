// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFTDemo is ERC721URIStorage {
	constructor (string memory name, string memory symbol) ERC721(name, symbol) {

	}
}