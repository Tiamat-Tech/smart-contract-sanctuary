// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract PIHHHToken is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    bool public saleIsActive = false;

    constructor() ERC721("PIHHHToken11", "PIHHH11") {}
    
    
    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }
    
    function getSaleState() external onlyOwner view returns(bool)   {
        return saleIsActive;
    }
    
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function safeMint(address to) public onlyOwner {
        require(saleIsActive, "Sale must be active to mint Creature");
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function safeMintURI(address to, string memory tokenURI) public onlyOwner {
        require(saleIsActive, "Sale must be active to mint Cards");
        _safeMint(to, _tokenIdCounter.current());
        _setTokenURI( _tokenIdCounter.current(), tokenURI);
        _tokenIdCounter.increment();
    }
    
    function safeMintURI(address to,uint256 numToken, string memory tokenURI) public onlyOwner {
        require(saleIsActive, "Sale must be active to mint Cards");
        _safeMint(to, numToken);
        _setTokenURI( numToken, tokenURI);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}