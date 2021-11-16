//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TapiocaTown is ERC721URIStorageUpgradeable, OwnableUpgradeable {
    uint256 private _price;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    function initialize() initializer public {
        __ERC721_init("TapiocaTown", "BOBA");
    }

    function setMintPrice(uint256 price) public onlyOwner {
        _price = price;
        return;
    }

    function getMintPrice() public view returns (uint256) {
        return _price;
    }

    function mintNFT(address recipient, string memory tokenURI) public virtual payable returns (uint256) {
        require(msg.value >= _price, "Not enough ETH");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}