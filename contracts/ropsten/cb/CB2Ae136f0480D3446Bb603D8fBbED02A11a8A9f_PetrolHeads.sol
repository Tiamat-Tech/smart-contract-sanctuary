// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@1001-digital/erc721-extensions/contracts/RandomlyAssigned.sol";

import "./ERC721CustomEnumerable.sol";

contract PetrolHeads is
    ERC721,
    Ownable,
    Pausable,
    ERC721Burnable,
    RandomlyAssigned,
    ERC721CustomEnumerable
{
    uint256 public constant MAX_TOKENS = 10000;
    uint256 public constant PRICE = 0.025 ether;
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721CustomEnumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721CustomEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}