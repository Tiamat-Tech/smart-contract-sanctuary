// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract emc9469 is ERC721, Ownable {

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token to uri
    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC721("EMC9469", "EMC9469") {}

    function mint(address to, uint256 tokenId, string memory tokenURI) public onlyOwner {
        _mint(to, tokenId);
        _tokenURIs[tokenId] = tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
}