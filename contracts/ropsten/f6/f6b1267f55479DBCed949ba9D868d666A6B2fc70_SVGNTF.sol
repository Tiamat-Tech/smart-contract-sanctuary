//SPDX-License-Identifier: Unlicense
//give the contract SVG code
//Output will be the NFT of that SVG
//Store that NFT MateData on Chain

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; //contract is simple counter countrat to create NFT ID but it implemete on library and storage classs so data will not lose

import "./helperContract.sol";

contract SVGNTF is ERC721URIStorage, helperContract {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    //event
    event CreateSVGNFT(uint256 index, string tokenURI);

    constructor() ERC721("SVG NTF Token ", "TKSVGNFT") {
    }

    function createNFT(string memory svg) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        string memory imageURI = svgToImageURI(svg);
        string memory NFTName = string(
            abi.encodePacked("TK-NFT-", toString(newItemId))
        );
        string memory tokenURI = formatTokenURI(NFTName, imageURI);

        //First create imageURI
        //Second create TokenURI

        _setTokenURI(newItemId, tokenURI);
        emit CreateSVGNFT(newItemId,tokenURI);
        return newItemId;
    }
}