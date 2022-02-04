//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "erc721a/contracts/ERC721A.sol";

contract NFTTest0 is ERC721A {
    // third argument is `maxBatchSize` refers to how much a minter can mint 
    // at a time.
    constructor() ERC721A("NFTTest0", "NFTTEST0", 4) {}

    function mint(uint256 quantity) external payable {
        // _safeMint's second argument now takes in a quantity, not a tokenId.
        _safeMint(msg.sender, quantity);
    }
}