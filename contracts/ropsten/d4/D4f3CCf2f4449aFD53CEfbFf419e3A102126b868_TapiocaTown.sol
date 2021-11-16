//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TapiocaTown is ERC721URIStorage, Ownable {
    uint256 private _price;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("TapiocaTown", "BOBA") {}

//    event PriceChanged(uint256 price);

    function setMintPrice(uint256 price) public onlyOwner {
        _price = price;
        return;
  //      PriceChanged(price);
    }

    function getMintPrice() public view returns (uint256) {
        return _price;
    }

    function mintNFT(address recipient, string memory tokenURI) public virtual payable returns (uint256) {
        require(msg.value >= _price, "Not enough ETH sent; check price!");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}