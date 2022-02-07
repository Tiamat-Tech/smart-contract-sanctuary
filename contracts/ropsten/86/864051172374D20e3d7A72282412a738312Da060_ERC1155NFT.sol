// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155NFT is ERC1155{
    constructor(string memory tokenURI) ERC1155(tokenURI){
    }
    
    function createToken(address account, uint256 id, uint256 amount, bytes memory data, string memory tokenURI) public {
        _mint(account, id, amount, data);
        _setURI(tokenURI);
    }
}