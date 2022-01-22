// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract SoongNFT is ERC721URIStorage, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("SoongNFT", "SNFT") {}

    mapping(uint256 => address) public SoongToOwner;

    function mintSoongNFT(string memory tokenURI) external onlyOwner returns (uint256) {

        _tokenIds.increment();
        uint newTokenId = _tokenIds.current();
        SoongToOwner[newTokenId] = msg.sender;

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        return newTokenId;
    }

}