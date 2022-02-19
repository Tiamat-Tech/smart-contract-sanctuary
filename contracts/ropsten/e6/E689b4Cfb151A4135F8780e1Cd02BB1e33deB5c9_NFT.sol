// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.10;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721A, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 6666;
    uint256 public constant MAX_SUPPLY_PUBLIC_SALE = 5666;

    string private _baseTokenURI;
    string private _unrevealedURI;
    bool private isRevealed;

    // Public sale
    uint256 private publicSalePrice = 0.033 ether;
    uint256 private publicSaleMaxMintPerTransaction = 5;

    // Free sale
    uint256 private freeSaleMaxMintPerTransaction = 3;
    uint256 private freeSaleMaxMints = 3;
    bool private freeSaleStarted;
    uint256 private freeNFTsMinted;
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public numberOfTokensMinted;

    constructor(string memory baseURI, string memory unrevealedURI) ERC721A("WomenDoodles", "WDD") {
        _baseTokenURI = baseURI;
        _unrevealedURI = unrevealedURI;
    }

    //////////
    // Getters

    function _baseURI() internal view virtual override returns (string memory) {
        if (!isRevealed) {
            return _unrevealedURI;
        }

        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (!isRevealed) {
            return _unrevealedURI;
        }

        else {
            string memory baseURI = _baseURI();
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
        }
    }

    function calculatePrice(uint256 _count) public view returns(uint256) {
        return _count * publicSalePrice;
    }

    function isFreeSaleActive() view external returns(bool) {
        return freeSaleStarted;
    }

    function numberOfFreeNFTsMinted() view external returns(uint256) {
        return freeNFTsMinted;
    }

    //

    function mintNFTs(uint256 quantity) external payable
    {
        require(!freeSaleStarted, "Public sale not active!");
        require(totalSupply() + quantity <= MAX_SUPPLY_PUBLIC_SALE, "Not enough NFTs left!");
        require(quantity <= publicSaleMaxMintPerTransaction, "Quantity exceeds max mints per transaction!");
        require(quantity > 0, "Cannot mint 0 NFTs.");
        require(msg.value >= calculatePrice(quantity),"Not enough ether to purchase NFTs.");

        if (totalSupply() + quantity == MAX_SUPPLY_PUBLIC_SALE) {
            freeSaleStarted = true;
        }

        _safeMint(msg.sender, quantity);
    }

    function mintFreeNFTs(uint256 quantity) external {
        require(freeSaleStarted, "Free sale is not started!");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough NFTs left!");
        require(quantity <= freeSaleMaxMintPerTransaction, "Quantity exceeds max mints per transaction!");
        require(numberOfTokensMinted[msg.sender] <= freeSaleMaxMints, "Quantity exceeds max mints per account!");
        require(isWhitelisted[msg.sender], "Account is not whitelisted!");
        require(quantity > 0, "Cannot mint 0 NFTs.");

        freeNFTsMinted += quantity;
        _safeMint(msg.sender, quantity);
    }

    function tokensOf(address owner) public view returns (uint256[] memory) {
        uint256 count = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i; i < count; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    //////////////////
    // Owner functions 

    function setPublicSaleMaxMintPerTransaction(uint256 _publicSaleMaxMintPerTransaction) external onlyOwner {
        publicSaleMaxMintPerTransaction = _publicSaleMaxMintPerTransaction;
    }

    function setFreeSaleMaxMintPerTransaction(uint256 _freeSaleMaxMintPerTransaction) external onlyOwner {
        freeSaleMaxMintPerTransaction = _freeSaleMaxMintPerTransaction;
    }

    function setFreeSaleMaxMints(uint256 _freeSaleMaxMints) external onlyOwner {
        freeSaleMaxMints = _freeSaleMaxMints;
    }

    function addToWhitelist(address[] memory _addresses) external onlyOwner {
        for (uint256 i = 0;i < _addresses.length;i++) {
            isWhitelisted[_addresses[i]] = true;
        }
    }

    function removeFromWhitelist (address[] memory _addresses) external onlyOwner {
        for (uint256 i = 0;i < _addresses.length;i++) {
            isWhitelisted[_addresses[i]] = false;
        }
    }

    function toggleReveal() public onlyOwner {
        if (isRevealed) isRevealed = false;
        else isRevealed = true;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setUnrevealedURI(string memory unrevealedURI) public onlyOwner {
        _unrevealedURI = unrevealedURI;
    }

    function startFreeSale() external onlyOwner {
        freeSaleStarted = true;
    }

    function endFreeSale() external onlyOwner {
        freeSaleStarted = false;
    }

    function setPrice(uint256 price) external onlyOwner {
        publicSalePrice = price;
    }

    function mintNFTsOwner(uint256 quantity) external onlyOwner {
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough NFTs left!");

        _safeMint(msg.sender, quantity);
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}