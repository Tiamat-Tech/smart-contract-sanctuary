// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.2;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WatchSkins is Ownable, ERC721 {

    event BaseURIChange(string baseURI);

    constructor () public ERC721("WATCH SKINS", "SKINS")
    {
        setBaseURI("https://ipfs.io/ipfs/");   // Eg: https://ipfs.io/ipfs/
    }

    /**
     * @dev Sets the base URI for the registry metadata
     * @param holder Address for the holder
     * @param tokenId tokenId for the skin
     * @param tokenURI url for the skin
     */
    function createItem(address holder, uint256 tokenId, string memory tokenURI)
        public
        returns (uint256)
    {
        _mint(holder, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }

    /**
     * @dev Sets the base URI for the skin metadata
     * @param _baseUri baseURL for the skin metadata
     */
    function setBaseURI(string memory _baseUri) public onlyOwner {
        _setBaseURI(_baseUri);
        emit BaseURIChange(_baseUri);
    }
}