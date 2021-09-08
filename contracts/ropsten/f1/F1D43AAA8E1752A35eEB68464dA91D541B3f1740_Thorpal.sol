// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Thorpal is Context, Ownable, ERC721, ERC721Enumerable {
    using Counters for Counters.Counter;

    uint public constant MAX_SUPPLY = 8;
    uint public constant SALE_PRIVATE_LENGTH = 2 hours;
    uint public constant SALE_PUBLIC_LENGTH = 2 hours;
    Counters.Counter public tokenIdCounter;
    string private _baseTokenURI;
    uint public saleStart;
    mapping(address => uint) public saleParticipants;

    constructor(
        string memory name,
        string memory symbol,
        string memory uri,
        uint _saleStart
    ) ERC721(name, symbol) Ownable() {
        _baseTokenURI = uri;
        saleStart = _saleStart;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata uri) public onlyOwner {
        _baseTokenURI = uri;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function mintPresale(uint count) public payable {
        require(block.timestamp >= saleStart, "pre-sale not started");
        require(block.timestamp <= saleStart + SALE_PRIVATE_LENGTH + SALE_PUBLIC_LENGTH, "sale ended");
        require(count <= 5, "max 5 tokens minted");
        _mint(count);
    }

    function mint(uint count) public payable {
        require(block.timestamp >= saleStart + SALE_PRIVATE_LENGTH, "sale not started");
        require(block.timestamp <= saleStart + SALE_PRIVATE_LENGTH + SALE_PUBLIC_LENGTH, "sale ended");
        _mint(count);
    }

    function _mint(uint count) internal {
        require(count > 0, "min 1 token minted");
        require(saleParticipants[msg.sender] + count <= 5, "max 5 tokens minted per address");
        require(totalSupply() + count < MAX_SUPPLY, "reached max supply");
        require(msg.value >= count * 0.08 ether);
        saleParticipants[msg.sender] += count;
        for (uint i = 0; i < count; i++) {
            _mint(msg.sender, tokenIdCounter.current());
            tokenIdCounter.increment();
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}