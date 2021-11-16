// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract UserNftMinter is ERC721URIStorage {
    uint256 public tokenId = 0;

    constructor() ERC721("UserNftMinter", "XPNFT-Test") {} // solhint-disable-line no-empty-blocks

    function mint(string calldata uri) public {
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        tokenId += 1;
    }

    function burn(uint256 id) public {
        address owner = ownerOf(id);
        require(owner == msg.sender, "caller doesn't own this nft");
        _burn(id);
    }
}