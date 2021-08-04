//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Cypher is ERC721 {


	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;

	uint256 public tokensLimit;
	uint256 public tokesMinted;
	uint256 public tokesAvailable;

	event UpdateCounts(uint256 tokensMinted,uint256 tokensAvailable);

	constructor(uint256 tokensLimitInit) public ERC721("Cypher","CYPHER") {
		tokensLimit = tokensLimitInit;
		tokesMinted = 0;
		tokesAvailable = tokensLimitInit;

	}

	function mintToken(address to, string memory uri) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 10000000,"Not enough ETH sent");
		require(tokesAvailable >= 1,"All tokens have been minted");

		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uri);


		uint256 tokensMinted = newItemId;
		uint256 tokesAvailable = tokensLimit - newItemId;

		emit UpdateCounts(tokensMinted,tokesAvailable);

		return newItemId;
	}
}