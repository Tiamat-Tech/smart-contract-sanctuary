// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PetrolHeads is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ERC721Burnable
{
    using Counters for Counters.Counter;

    uint256 public constant MAX_TOKENS = 10000;
    uint256 public constant PRICE = 25_000_000_000_000_000; // 0.025 ETH
    uint256 public constant PURCHASE_LIMIT = 20;
    string private _tokenBaseURI = "";
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("PETROL_HEADS", "HEADS") {}

    function mint(address to, string memory _tokenURI) external onlyOwner {
        _mint(to, _tokenURI);
    }

    function purchase(uint256 numberOfTokens) external payable whenNotPaused {
        require(
            numberOfTokens <= PURCHASE_LIMIT,
            "Can only mint up to 20 tokens"
        );
        require(
            PRICE * numberOfTokens <= msg.value,
            "ETH amount is not sufficient"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mint(msg.sender, _tokenBaseURI);
        }
    }

    function updateTokenURI(uint256 tokenId, string memory _tokenURI)
        external
        onlyOwner
    {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _tokenBaseURI = baseURI;
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

    function _mint(address to, string memory _tokenURI) private {
        require(
            _tokenIdCounter.current() < MAX_TOKENS,
            "Max number of NFTs already minted"
        );

        _safeMint(to, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), _tokenURI);
        _tokenIdCounter.increment();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}