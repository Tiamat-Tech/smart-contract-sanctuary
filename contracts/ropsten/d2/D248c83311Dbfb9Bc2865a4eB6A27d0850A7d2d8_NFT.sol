// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";


contract NFT is Ownable, ERC721 {
    string private _currentBaseURI;
    uint256 private topIndex;

    struct NFTMetadata {
        string nftURI;
        string author;
        string title;
        uint256 price;
    }

    mapping(uint256 => NFTMetadata) public idToNFTMetadata;

    event Purchase(address indexed previousOwner, address indexed newOwner, uint256 nftID, uint256 price);
    event Minted(address indexed minter, uint256 nftID, string nftURI, uint256 price);
    event PriceUpdate(address indexed owner, uint256 nftID, uint256 oldPrice, uint256 newPrice);

    constructor(string memory baseURI, string memory name, string memory symbol) ERC721(name, symbol) {
        topIndex = 0;
        setBaseURI(baseURI);
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        _currentBaseURI = _newBaseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _currentBaseURI;
    }

    function mint(string memory _nftURI, string memory _author, string memory _title, uint256 _price) public returns (uint256) {
        uint256 nftID = topIndex + 1;
        topIndex = nftID; // update index
        
        idToNFTMetadata[nftID] = NFTMetadata(_nftURI, _author, _title, _price);
        _safeMint(msg.sender, nftID);

        emit Minted(msg.sender, nftID, _nftURI, _price);

        return nftID;
    }

    function trade(uint256 _nftID) external payable {
        address payable buyer = payable(msg.sender);
        address payable owner = payable(ownerOf(_nftID));

        _transfer(owner, buyer, _nftID);

        uint256 price = idToNFTMetadata[_nftID].price;
        require(msg.value == price, "Incorrect price");
        owner.transfer(price);

        emit Purchase(owner, buyer, _nftID, price);
    }

    function updatePrice(uint256 _nftID, uint256 _newPrice) public {
        require(msg.sender == ownerOf(_nftID), "Only owner can change price");

        uint256 oldPrice = idToNFTMetadata[_nftID].price;
        require(oldPrice != _newPrice, "Same price");
        idToNFTMetadata[_nftID].price = _newPrice;

        emit PriceUpdate(msg.sender, _nftID, oldPrice, _newPrice);
    }

    function get(uint256 _nftID) external view returns (NFTMetadata memory) {
        require(_exists(_nftID), "token not minted");

        return idToNFTMetadata[_nftID];
    }
}