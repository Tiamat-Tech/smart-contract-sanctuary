// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


//ProCoreNFT Contract

contract ProCoreNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public MINT_PRICE = 50000000 gwei; // 0.05 eth
    uint256 public maxTokenSupply = 10000;
    uint256 public constant MAX_MINTS_PER_TXN = 10;
    bool public saleIsActive = false;
    string public baseURI;
    address[3] private _shareholders;

    constructor() public ERC721("ProCoreNFT", "NFT") {
        _shareholders[0] = 0x73C93932aDD9863B12B56d2A734674f19d14D514; //
        _shareholders[1] = 0xc816E96873fCa8f5586699CbBe06f8312Bd7eF39;// ProCoreNFT
        _shareholders[2] = 0x1eb4C3F1Ac40bD91E23E4a7aEE18de2479095c1f; //Com Wal
    }

    function mintNFT(address recipient, string memory tokenURI, uint256 numberOfTokens)
        public payable
        returns (uint256)
    {
        //require(saleIsActive, "Sale must be active to create planets");
        require(numberOfTokens <= MAX_MINTS_PER_TXN, "You can only create 10 planets at a time");
        //require(totalSupply() + numberOfTokens <= maxTokenSupply, "Purchase would exceed max available planets");
        require(MINT_PRICE * numberOfTokens <= msg.value, "Ether value sent is not correct");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function setMintPrice(uint256 newPrice) public onlyOwner {
        MINT_PRICE = newPrice;
    }

    /*
    * Pause sale if active, make active if paused.
    */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function setTokenURI(
        uint256 tokenId, 
        string memory tokenURI
    ) external {
        _setTokenURI(tokenId, tokenURI);
    }
    
    function setBaseURI(string memory baseURI_) external {
        baseURI = baseURI_;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}