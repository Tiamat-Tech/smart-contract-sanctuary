//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract BlockchainBackedItem is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => bool) public isLostOrStolen;
    mapping(uint256 => string) public ownerInfo;

    constructor() public ERC721("PixelJewellery", "BBI") {}

    function mintBBI(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function setLostOrStolen(uint256 tokenId)
        public onlyOwner
    {
        require(_exists(tokenId), "BlockchainBackedItem: attempt to set lost on nonexistent token");
        isLostOrStolen[tokenId] = true;
    }

    function setRecovered(uint256 tokenId)
        public onlyOwner
    {
        require(_exists(tokenId), "BlockchainBackedItem: attempt to set recovered on nonexistent token");
        isLostOrStolen[tokenId] = false;
    }

    function setOwnerInfo(uint256 tokenId, string memory info)
        public onlyOwner
    {
        require(_exists(tokenId), "BlockchainBackedItem: attempt to set the owner on nonexistent token");
        ownerInfo[tokenId] = info;
    }
}