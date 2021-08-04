//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Cyphers is ERC721 {
	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;

	constructor() public ERC721("Cyphers","NFT") {}

	function mintToken(address to, string memory uri) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 10000000,"Not enough ETH sent");
		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uri);
		return newItemId;
	}
}