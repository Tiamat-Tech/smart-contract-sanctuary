// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract Asset is ERC721, Mintable {
    constructor(
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_imx) {}

    function _mintFor(
        address to,
        uint256 id,
        bytes calldata
    ) internal override {
        _safeMint(to, id);
    }
}