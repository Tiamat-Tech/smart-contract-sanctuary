// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import {Base64} from "./libraries/Base64.sol";

contract TopCloudNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string public collectionName;
    string public collectionSymbol;

    constructor() ERC721("TopCloudNFT", "NFT") {
        collectionName = name();
        collectionSymbol = symbol();
    }

    function topcloudMintNFT(string memory tokenURI, uint256 newItemId)
        public
        returns (uint256)
    {
        string memory json = Base64.encode(
            bytes(string(abi.encodePacked(tokenURI)))
        );

        string memory finalTokenURI = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        _tokenIds.increment();

        // uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, finalTokenURI);

        return newItemId;
    }
}