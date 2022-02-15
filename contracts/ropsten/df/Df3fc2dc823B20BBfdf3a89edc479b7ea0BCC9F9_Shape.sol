// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Shape is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Shape", "SSS") {}

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function test(string memory testStr) public pure returns (string memory) {
        // usecase: testStr is "alfa" = alfa!
        string memory appendix = "!";
        string memory result = string(abi.encodePacked(testStr, appendix));
        return result;
    }

    // Draw NFT
    function drawSVG(
        string memory shape, //done
        string memory color, 
        string memory size 
        ) 
        public pure returns (string memory) {
        string memory svg;
        string memory _svg1;
        string memory _svg2;

        string memory _points;

        if (keccak256(abi.encodePacked((shape))) == keccak256(abi.encodePacked(("circle")))) {
            // "<svg width='640' height='200' viewBox='0 0 640 200' fill='none' xmlns='http://www.w3.org/2000/svg'><circle cx='100' cy='100' r='${size / 2}' fill='${color}' /></svg>"
            _svg1 = "<svg width='640' height='200' viewBox='0 0 640 200' fill='none' xmlns='http://www.w3.org/2000/svg'><circle cx=";
            _svg2 = string(abi.encodePacked(size, " cy=", size, " r=",size, " fill=", color, " /></svg>"));
            svg = string(abi.encodePacked(_svg1, _svg2));
        } else if (keccak256(abi.encodePacked((shape))) == keccak256(abi.encodePacked(("square")))) {
            _svg1 = "<svg width='640' height='200' viewBox='0 0 640 200' fill='none' xmlns='http://www.w3.org/2000/svg'><rect width=";
            _svg2 = string(abi.encodePacked(size, " height=", size, " fill=", color, " /></svg>"));
            svg = string(abi.encodePacked(_svg1, _svg2));
        } else if (keccak256(abi.encodePacked((shape))) == keccak256(abi.encodePacked(("triangle")))) {
            // `<svg width="640" height="200" viewBox="0 0 640 200" fill="none" xmlns="http://www.w3.org/2000/svg"><polygon points="50,0 ${size},100 0,100" style="fill:${color};" /></svg>`;
            _svg1 = "<svg width='640' height='200' viewBox='0 0 640 200' fill='none' xmlns='http://www.w3.org/2000/svg'><polygon points=";
            _points = string(abi.encodePacked("50,0 ", size, ",100 0 , 100"));
            _svg2 = string(abi.encodePacked("'",_points,"'", " style='fill:", color, ";' /></svg>"));
            svg = string(abi.encodePacked(_svg1, _svg2));
        }

        return svg;
    }

    // Set the owner of NFT to message.sender

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}