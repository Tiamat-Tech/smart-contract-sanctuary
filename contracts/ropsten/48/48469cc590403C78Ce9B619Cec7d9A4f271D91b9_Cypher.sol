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
	uint256 public tokensMinted;
	uint256 public tokensAvailable;

	event UpdateTokenCounts(uint256 tokensMintedNew,uint256 tokensAvailableNew);

	constructor(uint256 tokensLimitInit) public ERC721("Cypher","CYPHER") {
		tokensLimit = tokensLimitInit;
		tokensAvailable = tokensLimitInit;
		tokensMinted = 0;

	}

	function mintToken(address to, string memory uri) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 10000000,"Not enough ETH sent");
		require(tokensAvailable >= 1,"All tokens have been minted");

		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uri);


		tokensMinted = newItemId;
		tokensAvailable = tokensLimit - newItemId;

		emit UpdateTokenCounts(tokensMinted,tokensAvailable);

		return newItemId;
	}

	function mintFiveTokens(address to, string memory uri,string memory uriTwo,string memory uriThree,string memory uriFour,string memory uriFive) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 50000000,"Not enough ETH sent");
		require(tokensAvailable >= 5,"All tokens have been minted");

		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uri);

		_tokenIds.increment();
		newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uriTwo);

		_tokenIds.increment();
		newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uriThree);

		_tokenIds.increment();
		newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uriFour);

		_tokenIds.increment();
		newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uriFive);


		tokensMinted = newItemId;
		tokensAvailable = tokensLimit - newItemId;

		emit UpdateTokenCounts(tokensMinted,tokensAvailable);

		return newItemId;
	}




}