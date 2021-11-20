// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Infant is Ownable, ERC721Enumerable {
    uint256 public constant mintPrice = 0.01 ether;
    uint256 public constant mintLimit = 20;

    uint256 public supplyLimit = 10000;

    string public baseURI = "";

    address private creatorAddress = 0x0000000000000000000000000000000000000000; // creator
    address private devAddress = 0x0000000000000000000000000000000000000000; // developer

    bool public saleActive = true;

    constructor() ERC721("Infant", "NFT") {}

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string calldata newBaseUri) external onlyOwner {
        baseURI = newBaseUri;
    }

    function set(string calldata newBaseUri) external onlyOwner {
        baseURI = newBaseUri;
    }

    function setSaleActive(bool newSaleActive) external onlyOwner {
        saleActive = newSaleActive;
    }

    function getSaleActive() public view returns(bool) {
        return saleActive == true;
    }
    
    function mintInfant(uint numberOfTokens) external payable {
        require(getSaleActive(), "Sale is not active");
        require(numberOfTokens <= mintLimit, "Too many tokens for one transaction");
        require(msg.value >= mintPrice * numberOfTokens, "Insufficient payment");

        _mintInfant(msg.sender, numberOfTokens);
    }

    function _mintInfant(address to, uint numberOfTokens) private {
        require(totalSupply() + numberOfTokens <= supplyLimit, "Not enough tokens left");

        uint256 newId = totalSupply();
        for(uint i = 0; i < numberOfTokens; i++) {
            newId += 1;
            _safeMint(to, newId);
        }
    }

    function reserve(address to, uint256 numberOfTokens) external onlyOwner {
        _mintInfant(to, numberOfTokens);
    }

    function withdraw(bool entire, uint256 amount) external onlyOwner {
        require(address(this).balance > 0, "No balance to withdraw");

        uint256 total = address(this).balance;
        if (!entire) {
            total = amount;
        }

        uint devShare = total / 100 * 20;
        uint creatorShare = total - devShare;

        (bool success, ) = devAddress.call{value: devShare}("");
        require(success, "Withdrawal failed");

        (success, ) = creatorAddress.call{value: creatorShare}("");
        require(success, "Withdrawal failed");
    }

    function tokensOwnedBy(address wallet) external view returns(uint256[] memory) {
        uint tokenCount = balanceOf(wallet);

        uint256[] memory ownedTokenIds = new uint256[](tokenCount);
        for(uint i = 0; i < tokenCount; i++){
            ownedTokenIds[i] = tokenOfOwnerByIndex(wallet, i);
        }

        return ownedTokenIds;
    }
}