//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721.sol";
import "Counters.sol";
import "Ownable.sol";
import "ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    address payable private _contract_owner;    
    address payable private _creator;
    uint256 private _sell_interest_creator = 5;
    uint256 private _sell_interest_contract = 5;
    

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (uint256 => uint256) private tokenListing;
    

    constructor(address payable creator) public ERC721("MyNFT", "NFT") 
    {
	_contract_owner = payable(msg.sender);
	_creator = creator;	
    }

    function mintNFT(address payable recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
	approve (address(this), newItemId);
        return newItemId;
    }

   function listToken (uint256 tokenId, uint256 price)
	public 
	returns (uint256)
   {
	require(tokenId <= _tokenIds.current(), "Token does not exist.");
	require(ERC721.ownerOf(tokenId) == msg.sender, "You do not own this token.");
	require(price > 0, "Price must be at least 1 wei");
	tokenListing[tokenId] = price;
	return tokenListing[tokenId];
   }

   function unlistToken (uint256 tokenId)
	public
	returns (bool)
   {
	require(tokenId <= _tokenIds.current(), "Token does not exist.");
	require(ERC721.ownerOf(tokenId) == msg.sender, "You do not own this token.");
	require(tokenListing[tokenId] > 0, "Token is not listed currently.");
	tokenListing[tokenId] = 0;
	return tokenListing[tokenId] == 0;
   }

   function getListedPriceOf (uint256 tokenId)
	public view
	returns (uint256)
   {
	require(tokenId <= _tokenIds.current(), "Token does not exist.");
	require(tokenListing[tokenId] > 0, "Token ID not listed currently.");
	return tokenListing[tokenId];
   }	

   function buyListedPrice (uint256 tokenId)
	public 
   {
	require (tokenListing[tokenId] > 0, "Token ID not listed currently.");
	//address payable current_owner = payable(ERC721.ownerOf(tokenId));
        _contract_owner.transfer(tokenListing[tokenId]);
	
	// ERC721.safeTransferFrom(ERC721.ownerOf(tokenId), msg.sender, tokenId);
   }
}