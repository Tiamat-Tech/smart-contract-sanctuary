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
    bool public isLostOrStolen = false;
    string public ownerInfo;

    constructor() public ERC721("PixelEarring", "BlockchainBackedItem") {}

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

    function setLostOrStolen()
        public onlyOwner
    {
        isLostOrStolen = true;
    }

    function setRecovered()
        public onlyOwner
    {
        isLostOrStolen = false;
    }

    function setOwnerInfo(string memory info)
        public onlyOwner
    {
        ownerInfo = info;
    }
}