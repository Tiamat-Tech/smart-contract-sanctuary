// Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bytes32 public merkleRoot = 0x8beb93e8eb6321920a9b621c8a8cce4575ae26e0a63d4a1bb33b9c54336185e0;

    constructor() public ERC721("VL NFT", "VL-NFT") {}

    function whitelistMint(bytes32[] calldata _merkleProof, address recipient, string memory baseTokenURI)
        public
        returns (uint256)
    {
        bytes32 leaf = keccak256(abi.encodePacked(recipient));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof.");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);

        string memory tokenURI = string(abi.encodePacked(baseTokenURI, Strings.toString(newItemId), ".png"));

        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}