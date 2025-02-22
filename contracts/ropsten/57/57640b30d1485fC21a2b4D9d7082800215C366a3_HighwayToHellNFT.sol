// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract HighwayToHellNFT is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC721("HighwayToHellNFT", "H2H") {}

    function getBridgedNFT(string memory oldTokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(_msgSender(), newTokenId);
        _tokenURIs[newTokenId] = oldTokenURI;

        return newTokenId;
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }

    function tokenURI(uint256 tokenID) public view override returns (string memory)  {
        // require(_msgSender() == ERC721.ownerOf(tokenID));
        return _tokenURIs[tokenID];
    }

    function numMinted() public view returns (uint256)  {
        // require(_msgSender() == ERC721.ownerOf(tokenID));
        return _tokenIds.current();
    }
}