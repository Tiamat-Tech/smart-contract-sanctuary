pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";

/// @title contract for Nft-art tokens
 contract Nft is ERC721PresetMinterPauserAutoId {
	 using Counters for Counters.Counter;

	 /// @notice contract constructor.
	 /// @param name - Name
	 /// @param symbol - symbol
	 /// @param baseUri - baseUri of Nft.totalSupply();
	constructor 
	(string memory name, 
	string memory symbol, 
	string memory baseUri)
	 ERC721PresetMinterPauserAutoId(name, symbol, baseUri) {
	}

	mapping(string => uint8) hashes;	/// Records if hash already used.

	/// @notice Function for creating Nft.
	/// @param recipient - recipient of created nft.
	/// @param hash - hash of image of nft.
	/// @param metadata - hash of metadata file for the asset.
	function createCard(address recipient, string memory hash, string memory metadata) public returns (uint256) {

	require(hashes[hash] != 1);	// Checks if nft hash already used.

	hashes[hash] = 1;	// Records that hash became in use.

	uint256 tokenId = _tokenIdTracker.current();	// calls Id for nft.

	_tokenIdTracker.increment();	// increases id for 1.

	_mint(recipient, tokenId); // mints nft for recipient with this token id.

	_setTokenURI(tokenId, metadata);	// matches token uri for token id.

	return tokenId;
	}
}