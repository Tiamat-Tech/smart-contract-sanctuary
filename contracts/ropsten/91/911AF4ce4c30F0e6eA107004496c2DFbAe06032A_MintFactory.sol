//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintFactory is ERC721, ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    uint256 public constant TOTAL = 20;
    uint256 public constant MAX_PER_TRANSACTION = 10;
    uint256 public constant PRICE = 0.001 ether;
    string private URI;
    bool public active = false;
    Counters.Counter private _tokenIds;

    constructor(string memory tokenName, string memory symbol)
        ERC721(tokenName, symbol)
    {}

    function mint(uint256 count) public payable {
        uint256 total = totalSupply();
        require(total != TOTAL, "Sale must not be over");
        require(
            total.add(count) <= TOTAL,
            "Total purchases should not exceed max mints"
        );
        require(count > 0, "Order must be greater than zero");
        require(count <= MAX_PER_TRANSACTION, "Per transaction max exceeded");
        require(PRICE.mul(count) == msg.value, "Incorrect eth sent");
        for (uint256 i = 0; i < count; i++) {
            uint256 id = _tokenIds.current();
            _safeMint(msg.sender, id);
            _tokenIds.increment();
        }
    }

    function toggleActive() external onlyOwner {
        active = !active;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setURI(string memory _URI) external onlyOwner {
        URI = _URI;
    }

    function _baseURI() internal view override returns (string memory) {
        return URI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
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