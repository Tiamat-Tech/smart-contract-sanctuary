// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TwentyHeroes is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    //======================================== VARIABLES ========================================

    //track token ids
    Counters.Counter private tokenCount;

    //max tokens
    uint8 MAX_HEROES = 20;

    //new NFT minted
    event newHero(uint256 newToken);

    //======================================== FUNCTIONS ========================================

    constructor()
        ERC721("Twenty Heroes", "HEROES")
    {}

    function getCount() public view returns (uint256) {
        return tokenCount.current();
    }

    //override for derived contract, not called
    function _burn(uint256 _tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(_tokenId);
    }

    //override for derived contract
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_tokenId);
    }

    //mint new token
    function safeMint(address _to, string memory _tokenURI) public onlyOwner {
        uint256 newTokenId = tokenCount.current();
        require(newTokenId < MAX_HEROES, "Max number of heroes already minted");
        _safeMint(_to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        tokenCount.increment();
        emit newHero(newTokenId);
    }
}