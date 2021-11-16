// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract ImmutableX is ERC721, Mintable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) public idToName;
    mapping(uint256 => address) public idToAddress;
    address imx2 = 0x5FDCCA53617f4d2b9134B29090C87D01058e27e9;

    constructor() ERC721("ITEST", "ITSX") Mintable(msg.sender, imx2) {}

    function setName(uint256 tokenId, string memory _name) public {
        idToName[tokenId] = _name;
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
        idToAddress[id] = user;
    }
}