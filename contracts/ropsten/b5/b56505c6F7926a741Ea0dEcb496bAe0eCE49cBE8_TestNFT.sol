//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TestNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string private _myBaseURI;
    uint256 private _nftMaxCount;
    uint256 private _price;
    uint private _mintStart;
    uint private _mintEnd;

    constructor(string memory name_, string memory symbol_, string memory baseURI_, uint256 nftMaxCount_, uint256 price_) ERC721(name_, symbol_) {
        _myBaseURI = baseURI_;
        _nftMaxCount = nftMaxCount_;
        _price = price_;
    }

    function getNftMaxCount() public view returns (uint256) {
        return _nftMaxCount;
    }

    function getBaseURI() public view returns (string memory) {
        return _myBaseURI;
    }

    function getNftCount() public view returns (uint256) {
        return _tokenIds.current();
    }

    function setMintPrice(uint256 price_) public onlyOwner {
        _price = price_;
    }

    function getMintPrice() public view returns (uint256) {
        return _price;
    }

    function getTime() public view returns (uint) {
        return block.timestamp;
    }

    function setMintStart(uint date) public onlyOwner {
        _mintStart = date;
    }

    function setMintEnd(uint date) public onlyOwner {
        _mintEnd = date;
    }

    function setMintRange(uint from, uint to) public onlyOwner {
        _mintStart = from;
        _mintEnd = to;
    }

    function getMintStart() public view returns (uint) {
        return _mintStart;
    }

    function getMintEnd() public view returns (uint) {
        return _mintEnd;
    }

    function mintNFT() public payable returns (uint256)
    {
        require(block.timestamp >= _mintStart, "Mint not started yet");
        require(block.timestamp <= _mintEnd, "Mint has been finished");
        require(_price == msg.value, string(abi.encodePacked("Wrong ETH: got ", Strings.toString(msg.value), " expected ", Strings.toString(_price))));

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();

        require(newItemId <= getNftMaxCount(), "Sold out!");

        string memory tokenURI = string(abi.encodePacked(_myBaseURI, Strings.toString(newItemId), ".json"));
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        payable(owner()).transfer(msg.value);

        return newItemId;
    }
}