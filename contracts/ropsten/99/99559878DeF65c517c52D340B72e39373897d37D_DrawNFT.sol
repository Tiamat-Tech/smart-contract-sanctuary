//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract DrawNFT is ERC721, Mintable {
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (blueprints[tokenId].length > 0) {
            delete blueprints[tokenId];
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "DrawNFT: URI query for nonexistent token");

        bytes memory blueprint = blueprints[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return string(blueprint);
        }
        // If both are set, concatenate the baseURI and blueprint (via abi.encodePacked).
        if (blueprint.length > 0) {
            return string(abi.encodePacked(base, string(blueprint)));
        }

        return super.tokenURI(tokenId);
    }
}