pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract GreenCube is ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Cube {
        uint256 layerA;
        uint256 layerB;
        uint256 layerC;
        uint256 tokenId;
        string name;
    }

    mapping(uint256 => Cube) private _cubes;

    constructor() public ERC721("GreenCube", "NFT") {}

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function requestNewRandomCube() public returns (uint256) {
        uint256 tokenId = getNextTokenId();

        _cubes[tokenId] = Cube(
            0,
            0,
            0,
            tokenId,
            "Cube #"
        );

        return tokenId;
    }

    function getCubeById(uint256 tokenId) public view returns (uint256, uint256, uint256, string memory) {
        return (
        _cubes[tokenId].layerA,
        _cubes[tokenId].layerB,
        _cubes[tokenId].layerC,
        _cubes[tokenId].name
        );
    }

    function getNextTokenId() private returns (uint256) {
        _tokenIds.increment();
        return _tokenIds.current();
    }

    function mintNFT(address recipient, string memory tokenURI) public returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}