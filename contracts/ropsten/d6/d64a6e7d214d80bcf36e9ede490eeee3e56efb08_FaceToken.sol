// SPDX-License-Identifier: MIT
// Facenote (c) 2021, Facundo Monpelat
// Smart Contract Face Token v1.0.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract FaceToken is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;

    constructor() ERC721('FaceToken', 'FFT') {}

    function createFaceToken(address recipient, string memory tokenURI)
        public onlyOwner 
        returns(uint256)
    {
        _tokenId.increment();

        uint256 newFTId = _tokenId.current();
        _safeMint(recipient, newFTId);
        _setTokenURI(newFTId, tokenURI);

        return newFTId;
    }

}