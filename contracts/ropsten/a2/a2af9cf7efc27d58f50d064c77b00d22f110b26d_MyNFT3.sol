// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (token/ERC721/ERC721.sol)

pragma solidity 0.8.0; 

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; //contains the implementation of the ER721 standard
import "@openzeppelin/contracts/utils/Counters.sol"; //provides counters that can only be incremented or decremented by 1
import "@openzeppelin/contracts/access/Ownable.sol"; //sets up access control on our smart contracts - only the owner of the smart contract can mint NFTs

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT3 is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("MyNFT3", "NFT") {}

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
}