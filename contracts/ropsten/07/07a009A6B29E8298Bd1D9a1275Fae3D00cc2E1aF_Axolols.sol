// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Axolols is ERC721, ERC721Enumerable, Pausable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    uint256 public constant MAX_NFTS = 8888;
    uint256 public constant MAX_PER_MINT = 20;
    uint256 public reservedNum = 100;
    uint256 public price = 0.05 ether;
    string public baseURI = "https://api.coolcatsnft.com/cat/";

    constructor() ERC721("Axolols", "AXO") {
        pause();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function giveAway(address to) public onlyOwner {
        require(totalSupply() + 1 <= MAX_NFTS, "Exceeds max supply"); // giveaway can't go over total
        require(reservedNum > 0, "No more reserves"); // giveaway can't go more than reserved
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
        reservedNum--;
    }

    function changePrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function reserveMint(uint256 mintNum) public onlyOwner {
        require(totalSupply() + mintNum <= MAX_NFTS, "Exceeds max supply");
        require(mintNum > 0 && mintNum <= reservedNum, "Not enough reserves");

        for (uint256 i; i < mintNum; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            _tokenIdCounter.increment();
            reservedNum--;
        }
    }

    function publicMint(uint256 mintNum) public payable whenNotPaused {
        require(
            totalSupply() + mintNum <= MAX_NFTS - reservedNum,
            "Exceeds max supply"
        );
        require(
            mintNum > 0 && mintNum <= MAX_PER_MINT,
            "Exceeds max mint at a time"
        );
        require(msg.value >= price * mintNum, "Not enough ether");

        for (uint256 i; i < mintNum; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}