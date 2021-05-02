// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("https://example.com/{id}") {}

    function mint(
        address recipient,
        uint256 tokenId,
        uint256 tokenAmt
    ) public returns (uint256) {
        _mint(recipient, tokenId, tokenAmt, "");
        return tokenId;
    }
}