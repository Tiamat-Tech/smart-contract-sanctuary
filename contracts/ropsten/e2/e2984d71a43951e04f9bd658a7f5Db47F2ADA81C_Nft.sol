pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";

/// @title contract for Nft-art tokens
 contract Nft is ERC721PresetMinterPauserAutoId
{
	constructor 
	(string memory name, 
	string memory symbol, 
	string memory baseUri)
	 ERC721PresetMinterPauserAutoId(name, symbol, baseUri) 
	{
	}
}