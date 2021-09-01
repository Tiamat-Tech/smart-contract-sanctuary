//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Wheels is ERC721 {


	using Counters for Counters.Counter;
	Counters.Counter private _tokenIds;

	uint256 public tokensLimit;
	uint256 public tokensMinted;
	uint256 public tokensAvailable;

	address payable destinationAddressOne;

	event UpdateTokenCounts(uint256 tokensMintedNew,uint256 tokensAvailableNew);

	constructor(uint256 tokensLimitInit, address payable desAddressOneInit) public ERC721("Wheels","WHLZ") {
		tokensLimit = tokensLimitInit;
		tokensAvailable = tokensLimitInit;
		tokensMinted = 0;
		destinationAddressOne = desAddressOneInit;
	}

	function mintToken(address to, string memory uri) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 80000000000000000,"Not enough ETH sent");
		require(tokensAvailable >= 1,"All tokens have been minted");
		passOnEth(msg.value);

		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uri);


		tokensMinted = newItemId;
		tokensAvailable = tokensLimit - newItemId;

		emit UpdateTokenCounts(tokensMinted,tokensAvailable);

		return newItemId;
	}

	function mintTwoTokens(address to, string memory uri,string memory uriTwo) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 160000000000000000,"Not enough ETH sent");
		require(tokensAvailable >= 2,"All tokens have been minted");
		passOnEth(msg.value);

		_tokenIds.increment();
		uint256 newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uri);

		_tokenIds.increment();
		newItemId = _tokenIds.current();
		_mint(to,newItemId);
		_setTokenURI(newItemId, uriTwo);

		tokensMinted = newItemId;
		tokensAvailable = tokensLimit - newItemId;

		emit UpdateTokenCounts(tokensMinted,tokensAvailable);

		return newItemId;
	}


	function mintTenTokens(address to, string memory uri,string memory uriTwo,string memory uriThree,string memory uriFour) 
		public 
		virtual 
		payable 
		returns (uint256) 
	{
		require(msg.value >= 320000000000000000,"Not enough ETH sent");
		require(tokensAvailable >= 4,"All tokens have been minted");
		passOnEth(msg.value);

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

		
		tokensMinted = newItemId;
		tokensAvailable = tokensLimit - newItemId;

		emit UpdateTokenCounts(tokensMinted,tokensAvailable);

		return newItemId;
	}



	 function passOnEth(uint256 amount) public payable {
        // Call returns a boolean value indicating success or failure.
        // This is the current recommended method to use.

        uint singleAmount = amount;

        (bool sentToAddressOne, bytes memory dataToAddressOne) = destinationAddressOne.call{value: singleAmount}("");
        require(sentToAddressOne, "Failed to send Ether");

    }


}