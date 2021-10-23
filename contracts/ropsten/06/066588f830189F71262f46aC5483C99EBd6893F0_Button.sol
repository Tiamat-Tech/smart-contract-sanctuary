// Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Button is ERC721URIStorage, Ownable {

    constructor() ERC721("Button", "BTN") {}

    function mintNFT(address recipient, uint256 tokenId, string memory tokenURI)
        public onlyOwner
    {
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI);
    }
}