// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract ClubNervaMembership is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC721_init("ClubNervaMembership", "CNM");
        __ERC721URIStorage_init();
        __Ownable_init();
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _approve(owner(), tokenId);
    }
    
    // owner can change uri for a token if they have to
    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    //all the standard ERC721 can only be invoked by contract owner for now
    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721Upgradeable)
        onlyOwner
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data)
        public
        override(ERC721Upgradeable)
        onlyOwner
    {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721Upgradeable)
        onlyOwner
    {
        super.transferFrom(from, to, tokenId);
    }

    //some unsupported stuff
    function approve(address to, uint256 tokenId)
        public
        override(ERC721Upgradeable)
    {
        require(false, "Not supported!");

    }

    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721Upgradeable)
    {
        require(false, "Not supported!");
    }


    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    

    
}