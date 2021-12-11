// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DigitalSwag is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    string private _swagBaseURI;

    uint private _maxTokens;

    event BaseURIChanged(string baseURI);

    constructor() ERC721("Digital Swag", "DSWAG") {
        _swagBaseURI = "https://nftees.s3.amazonaws.com/tokens/";

        _maxTokens = 62;

        // Pre-Mint the first 12
        _tokenIdCounter.increment(); //burn 0

        for(uint i = 1; i <= 12; i++) {
            safeMint(owner());
        }
    }

    function mintSwag() public {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId <= _maxTokens, "DSWAG: Max Swag has been minted");
        require(balanceOf(msg.sender) == 0, "DSWAG: Only one mint per address");

        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId <= _maxTokens, "DSWAG: Max Swag has been minted");

        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _swagBaseURI;
    }

    function setSwagBaseURI(string memory baseURI) public onlyOwner {
        _swagBaseURI = baseURI;
        emit BaseURIChanged(_swagBaseURI);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
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