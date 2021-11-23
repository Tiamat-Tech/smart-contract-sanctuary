// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/security/Pausable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";

contract TEST9 is ERC721, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("TEST9", "999") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}