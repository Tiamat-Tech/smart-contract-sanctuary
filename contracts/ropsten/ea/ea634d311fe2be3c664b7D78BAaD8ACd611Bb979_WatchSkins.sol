// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.6.2;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract WatchSkins is Ownable, ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIds;

    event BaseURIChange(string baseURI);

    constructor () public ERC721("WATCH SKINS", "SKINS")
    {
        setBaseURI("https://ipfs.io/ipfs/");   // Eg: https://ipfs.io/ipfs/
    }

    /**
     * @dev Sets the base URI for the registry metadata
     * @param holder Address for the holder
     * @param tokenURI url for the skin
     */
    function createItem(address holder, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(holder, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
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