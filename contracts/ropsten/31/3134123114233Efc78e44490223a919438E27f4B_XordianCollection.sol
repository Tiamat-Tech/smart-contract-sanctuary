// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XordianCollection is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public constant baseExtension = ".json";
    string public baseURI;

    constructor(string memory _base) ERC721("XordCollection", "XCL") {
        setBaseURI(_base);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function mint(address _address, uint256 _tokenId) public onlyOwner {
        _safeMint(_address, _tokenId);
    }
    
    function mintMultiple(address _address, uint256[] memory _tokenIds) public onlyOwner {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _safeMint(_address, _tokenIds[i]);
        }
    }
       
}