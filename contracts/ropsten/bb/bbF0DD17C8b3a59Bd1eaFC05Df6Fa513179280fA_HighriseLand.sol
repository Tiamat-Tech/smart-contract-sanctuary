// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "ERC721.sol";
import "Mintable.sol";

contract HighriseLand is ERC721, Mintable {
    constructor(
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(msg.sender, _imx) {}

    function _mintFor(
        address user,
        uint256 tokenId,
        bytes memory blueprint
    ) internal override {
        _safeMint(user, tokenId, blueprint);
    }

    function _baseURI() internal view override returns (string memory) {
        return "s3://highrise-land/metadata/";
    }
}