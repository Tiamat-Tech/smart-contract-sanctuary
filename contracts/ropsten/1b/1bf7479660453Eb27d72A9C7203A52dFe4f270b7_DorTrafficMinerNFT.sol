//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract DorTrafficMinerNFT is ERC721, Ownable {
    string private _baseMetadataURI =
        "https://nfts.constellationnetwork.io/nfts/dtm/";

    constructor() ERC721("DorTrafficMiner", "DTM") {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseMetadataURI;
    }

    function setBaseURI(string memory newURI) public onlyOwner {
        _baseMetadataURI = newURI;
    }

    function getBaseURI() public view returns (string memory) {
        return _baseMetadataURI;
    }

    function renounceOwnership() public view override onlyOwner {
        revert("DorTrafficMinerNFT: This contract does not allow the renounceOwnership method");
    }
}