// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract Asset is ERC721, Mintable {
    constructor(string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Mintable(msg.sender, 0x4527BE8f31E2ebFbEF4fCADDb5a17447B27d2aef) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }
}