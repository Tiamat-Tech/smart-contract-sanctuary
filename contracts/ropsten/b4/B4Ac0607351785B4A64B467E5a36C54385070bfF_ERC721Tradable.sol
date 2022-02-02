// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IERC721Burnable.sol";
import "./interfaces/IERC721Mintable.sol";


/**
 * @title ERC721Tradable
 * ERC721Tradeable - ERC721 contract that whitelists a trading address, and has minting functionality.
 */
contract ERC721Tradable is ERC721Enumerable, Ownable, IERC721Burnable, IERC721Mintable {

    string constant tokenUri = "http://token_uri.com/";

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
    }

    /**
     * @dev Mints a token to an address with a tokenURI.
     * @param to_ address of the future owner of the token
     */
    function mintTo(address to_, uint256 tokenId_) override external onlyOwner {
        _mint(to_, tokenId_);
    }

    /**
     * @dev Mints a token to msg.signer.
     */
    function mint(uint256 tokenId_) override external onlyOwner {
        _mint(msg.sender, tokenId_);
    }

    /**
     * @dev Burns a token owned by msg.signer.
     */
    function burn(uint256 tokenId_) override external {
        require(_isApprovedOrOwner(msg.sender, tokenId_) == true, "Msg.sender not approved to burn");
        _burn(tokenId_);
    }

    /**
     * @dev returns uri where resources are hosted
     */
    function baseTokenURI() external pure returns (string memory) {
        return tokenUri;
    }

    /**
     * @dev returns uri where particular token is hosted
     */
    function tokenURI(uint256 _tokenId) override public pure returns (string memory) {
        return string(abi.encodePacked(tokenUri, Strings.toString(_tokenId)));
    }
}