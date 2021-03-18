//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract AutographContract is ERC721 {

    // struct Autograph {

    // }

// {
// "name": "Name for it ",
// "description": "Anything you want",
// "image": "https://ipfs.io/ipfs/HASH_HERE?file.png",
// "attributes": [...]
// }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;

    event Minted(uint id, address owner);

    // TODO: NFT as a struct? which attributes?
    // TODO: Implement EIP-2981 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: Check ERC-7128 extension contracts !!!!!!!!!!!!!!!!!!!!!!!!!

    constructor() ERC721("HashSign Token", "SIGN") {
        _setBaseURI("https://ipfs.io/ipfs/");
    }

    /** 
     * Function used to mint a new NFT.
     * _to: Person's wallet address who will receive the NFT.
     * _hash: IPFS hash associated with the content we are creating the NFT for.
     * _tokenURI: Link to an image referencing the asset. Might include the asset name, a link to an image referencing the asset, or anything you want.
     */
    function mint(address _to, string memory _hash, string memory _metadata) public returns (uint) {
        require(hashes[_hash] != 1); // Automatically reject the contract call if the hash has been used to mint an NFT before.
        hashes[_hash]=1;
        _tokenIds.increment();
        uint newItemId = _tokenIds.current();
        _safeMint(_to, newItemId);
        _setTokenURI(newItemId, _metadata);

        emit Minted(newItemId, _to);
        return newItemId;
    }



}