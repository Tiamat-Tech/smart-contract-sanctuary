// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MyERC1155Token is ERC1155 {
    uint256 public constant test1ERC20 = 1;

    uint256 public constant test4ERC721 = 2;

    uint256[] ids = [test1ERC20, test4ERC721];
    uint256[] amounts = [10**18, 1];

    constructor()
        ERC1155(
            "https://ipfs.io/ipfs/QmVZChHKZGKA96h7jqsF3KGsV17rEe5JBv38LGiqaFRpML/{id}.json"
        )
    {
        // _mint(msg.sender, test1ERC20, 10**18, "");
        // _mint(msg.sender, test4ERC721, 1, "");
    }

    function mintTokenInBatch(address to) public {
        _mintBatch(to, ids, amounts, "");
    }
}