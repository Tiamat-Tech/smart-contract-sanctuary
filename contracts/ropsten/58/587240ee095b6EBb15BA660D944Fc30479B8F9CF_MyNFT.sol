//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721.sol";
import "Counters.sol";
import "Ownable.sol";
import "ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (uint256 => uint256) private tokenListing;

    constructor() public ERC721("MyNFT", "NFT") {}

    function mintNFT(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

   function listToken (uint256 tokenId, uint256 price)
	public 
	returns (uint256)
   {
	require(ERC721.ownerOf(tokenId) == msg.sender, "You do not own this token!") ;
	require(price > 0, "Price must be at least 1 wei");
	tokenListing[tokenId] = price;
	return tokenListing[tokenId];
   }

   function getListedPriceOf (uint256 tokenId)
	public
	returns (uint256)
   {
	require(tokenListing[tokenId] > 0, "Token ID not listed currently");
	return tokenListing[tokenId];
   }	
}