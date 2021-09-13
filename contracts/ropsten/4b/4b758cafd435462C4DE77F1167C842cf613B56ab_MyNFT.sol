//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

// implementation of the ERC721 standard, which our NFT smart contract will inherit. 
// (To be a valid NFT, your smart contract must implement all the methods of the ERC721 standard.) 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// provides counters that can only be incremented or decremented by one
// Each NFT minted using a smart contract must be assigned a unique ID
// here our unique ID is just determined by the total number of NFTs in existance.
import "@openzeppelin/contracts/utils/Counters.sol";
// sets up access control on our smart contract, so only the owner of the smart contract (you) can mint NFTs. 
// including access control is entirely a preference. 
// for anyone to be able to mint an NFT using smart contract, remove the word Ownable on line 10 and onlyOwner on line 17.
import "@openzeppelin/contracts/access/Ownable.sol";

// most functions are inherited from openzeppelin
// such as ownerOf (returns the owner of the NFT) 
// transferFrom(transfers ownership of the NFT).
contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // the name and symbol of the smart contract
    constructor() public ERC721("MyNFT", "NFT") {}

    // address recipient: the address that will receive your freshly minted NFT
    // string memory tokenURI: a string that should resolve to a JSON document that describes the NFT's metadata
    // NFT's metadata includes properties such as a name, description, image, and other attributes
    function mintNFT(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        // a number that represents the ID of the freshly minted NFT.
        return newItemId;
    }
}