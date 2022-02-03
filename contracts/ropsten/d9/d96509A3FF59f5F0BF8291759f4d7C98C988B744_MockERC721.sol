//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Mintable by anybody. Basically a mock of our token sale.
 */

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract MockERC721 is ERC721Enumerable {
    uint256 constant MAX_SUPPLY = 8192;

    constructor() ERC721('RECESS RPS TICKET', 'RRT') {}

    function mint(uint256 count) external {
        require(totalSupply() + count < MAX_SUPPLY);
        for (uint256 i = 0; i < count; i++) {
            _safeMint(msg.sender, totalSupply());
        }
    }
}