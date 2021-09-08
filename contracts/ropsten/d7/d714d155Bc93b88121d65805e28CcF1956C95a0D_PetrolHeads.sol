// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@1001-digital/erc721-extensions/contracts/RandomlyAssigned.sol";

contract PetrolHeads is
    ERC721,
    Pausable,
    ERC721Burnable,
    RandomlyAssigned,
    Ownable
{
    uint256 public constant MAX_TOKENS = 10000;
    uint256 public constant PRICE = 25_000_000_000_000_000; // 0.025 ETH
    uint256 public constant PURCHASE_LIMIT = 20;
    string private _metadataBaseURI = "";

    constructor(string memory baseURI)
        ERC721("PETROL_HEADS", "HEADS")
        RandomlyAssigned(MAX_TOKENS, 0)
    {
        _metadataBaseURI = baseURI;
    }

    function purchase(uint256 numberOfTokens)
        external
        payable
        whenNotPaused
        ensureAvailabilityFor(numberOfTokens)
    {
        require(
            numberOfTokens <= PURCHASE_LIMIT,
            "Can only mint up to 20 tokens"
        );
        require(
            PRICE * numberOfTokens <= msg.value,
            "ETH amount is not sufficient"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 next = nextToken();
            console.log(next);
            _safeMint(msg.sender, next);
        }
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _metadataBaseURI = baseURI;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool succeed, ) = msg.sender.call{value: balance}("");
        require(succeed, "Failed to withdraw Ether");
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _metadataBaseURI;
    }
}