// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract BinanceTestnet is ERC721Enumerable {
    using Strings for uint256;

    string public baseURI = "https://public.nftstatic.com/static/nft/BSC/BMBLFW/";

    constructor(
    ) ERC721("LegendFantasyWar", "LFW1") {
    }

    function mint(uint256 num) public payable {
       _safeMint(msg.sender, num);
    }

    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        return index;
    }

    /**
     * override tokenURI(uint256), remove restrict for tokenId exist.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}