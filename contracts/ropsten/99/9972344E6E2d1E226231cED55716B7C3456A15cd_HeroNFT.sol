// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HeroNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    //======================================== VARIABLES ========================================

    //track token ids
    Counters.Counter private tokenCount;

    //new NFT minted
    event newHero(uint256 newToken);

    //======================================== FUNCTIONS ========================================

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function getCount() public view returns (uint256) {
        return tokenCount.current();
    }

    //override for derived contract
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
        _safeMint(_to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);
        tokenCount.increment();
        emit newHero(newTokenId);
    }
}