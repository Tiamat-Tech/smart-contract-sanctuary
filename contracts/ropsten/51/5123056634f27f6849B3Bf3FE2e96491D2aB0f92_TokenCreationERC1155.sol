//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TokenCreationERC1155 is ERC1155{
    uint256 public constant data1 = 1;
    uint256 public constant data2 = 2;
 
    uint256[] tokenId = [data1, data2];
    uint tokenIds = 3;
    string _uri;
    
    constructor() ERC1155("https://ipfs.io/ipfs/QmXe4KrxY9ebQNToxuTKJ1JRUrtEjSSvzaFrzW1DMm6UNx/{id}.json") {}
    
    function mintBatchToken(address to, uint256[] memory initalBatchSupply, string memory newuri) public{
        _mintBatch(to, tokenId, initalBatchSupply, ""); 
        _setURI(newuri);
    }

    function mintToken(address to, uint initalSupply, string memory newuri) public{
        _mint(to, tokenIds, initalSupply, "");
        tokenIds++;
        _setURI(newuri);
    }
}