//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract Cryptoweeds is ERC721URIStorage, ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    string public baseURI;
    uint256 public startingIndex = 1;
    uint256 public constant price = 1 * 1e16;
    uint256 public cap;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _cap
    ) ERC721(name, symbol) {
        cap = _cap;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function bookWeeds(uint256 _count) public onlyOwner {
        uint256 supply = totalSupply();
        uint256 i;
        for (i = 0; i < _count; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mint(uint256 amount) public payable {
        require(totalSupply().add(amount) <= cap, "Mint over the max nft amount");
        require(price.mul(amount) <= msg.value, "Value sent less than needed");

        for (uint256 i = 0; i < amount; i++) {
            uint256 index = totalSupply();
            _safeMint(msg.sender, index);
        }
    }
}