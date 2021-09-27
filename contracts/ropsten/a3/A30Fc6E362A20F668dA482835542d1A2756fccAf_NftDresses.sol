// contracts/NftDresses.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NftDresses is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 constant _maxCount = 2;

    constructor() ERC721("NFT-Dresses", "DRS") {}

    function mintNft(address receiver, string memory tokenURI)
        public
        returns (uint256)
    {
        uint256 nftTokenId = _tokenIds.current();
        require(nftTokenId < _maxCount, "Counter: maximum number of nft items");

        _tokenIds.increment();

        uint256 newNftTokenId = _tokenIds.current();
        _mint(receiver, newNftTokenId);
        _setTokenURI(newNftTokenId, tokenURI);

        return newNftTokenId;
    }
}