//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TapiocaTown is ERC721URIStorageUpgradeable, OwnableUpgradeable {
    uint256 private _price;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event PriceChanged(uint256 price);
    event MintId(uint256 nftId);

    function initialize() public initializer {
        __ERC721_init_unchained("TapiocaTown", "BOBA");
        __Ownable_init_unchained();
    }

    function setMintPrice(uint256 price) public onlyOwner {
        _price = price;
        emit PriceChanged(price);
        return;
    }

    function getMintPrice() public view returns (uint256) {
        return _price;
    }

    function mintNFT(address recipient, string memory tokenURI) public virtual payable returns (uint256) {
        require(msg.value >= _price, "Not enough ETH");

        _tokenIds.increment();

        uint256 newNftId = _tokenIds.current();
        _mint(recipient, newNftId);
        _setTokenURI(newNftId, tokenURI);

        MintId(newNftId);
        return newNftId;
    }
}