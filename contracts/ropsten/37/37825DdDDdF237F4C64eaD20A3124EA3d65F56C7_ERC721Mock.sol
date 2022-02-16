// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Mock is ERC721Enumerable {
    string private uri;
    address public minter;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _minter
    ) ERC721(_name, _symbol) {
        uri = _uri;
        minter = _minter;
    }

    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    function mint(address to, uint256 tokenId) public {
        require(msg.sender == minter, "The sender is not the sender.");
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function transferMinter(address newMinter) internal virtual {
        require(msg.sender == minter, "The sender is not the sender.");
        minter = newMinter;
    }
}