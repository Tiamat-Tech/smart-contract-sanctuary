// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @creator: redeem.coffee
/// @author: Wizard

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC721Redeemable.sol";

contract Redeemable is ERC721, ERC721Burnable, ERC721Redeemable, Ownable {
    string private baseURI;

    constructor() ERC721("Redeemable", "REDM") {}

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    function create(
        uint256 prefix,
        uint256 allowedRedemptions,
        string memory uri
    ) public onlyOwner {
        _create(prefix, allowedRedemptions, uri);
    }

    function mint(uint256 prefix, address to) public onlyOwner {
        _mint(prefix, to);
    }

    function _baseURI()
        internal
        view
        virtual
        override(ERC721)
        returns (string memory)
    {
        return baseURI;
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721Redeemable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}