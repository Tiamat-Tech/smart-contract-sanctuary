// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Puppytem is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Puppytem", "PUP") {}

    mapping(uint256 => string) tokenURIs;

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return tokenURIs[tokenId];
    }

    function create(address player, string memory mytokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        tokenURIs[newItemId] = mytokenURI;
        //_setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}