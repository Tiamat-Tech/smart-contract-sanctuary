// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NonFungibleToken/ERC721.sol";
import "./NonFungibleToken/ERC2981.sol";
import "./NonFungibleToken/extensions/ERC721Enumerable.sol";
import "./NonFungibleToken/extensions/ERC721URIStorage.sol";
import "./NonFungibleToken/extensions/ERC721Burnable.sol";
import "./NonFungibleToken/access/Ownable.sol";
import "./NonFungibleToken/utils/Counters.sol";

/**
 * @title NonFungibleToken contract
 *
 * @dev Extends ERC721 non-fungible token standard
 */
contract NonFungibleToken is ERC721, ERC2981, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    receive() external payable {}
    fallback() external payable {}

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    /**
     * @dev Sets the constructor values
     */
    constructor(address _owner, address _contract) ERC721("NFT CONTRACT", "TOKEN") {
        string memory URI = "ipfs://";
        _safeMint(_owner, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), URI);
        _tokenIdCounter.increment();

        _safeMint(_owner, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), URI);
        _tokenIdCounter.increment();

        _safeMint(_owner, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), URI);
        _tokenIdCounter.increment();

        _safeMint(_owner, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), URI);
        _tokenIdCounter.increment();

        setRoyalty(address(this));

        approve(_contract, 0);
        approve(_contract, 1);
        approve(_contract, 2);
        approve(_contract, 3);
    }

    // Override functions

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}