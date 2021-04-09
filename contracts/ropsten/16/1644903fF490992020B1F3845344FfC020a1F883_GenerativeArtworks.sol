pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract GenerativeArtworks is ERC721Enumerable {
    constructor() ERC721("Generative Artworks", "GA") {}
}