//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract catShelter is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _catIdCounter;

    constructor() ERC721("catShelter", "CHR") {}

    // struct Cat {
    //     string uri;
    //     string name;
    //     string color;
    //     string fluffLevel;
    //     uint8 age;
    // }

    // Cat[] cats;

    function _baseURI() internal pure override returns (string memory) {
        return "ttps://ipfs.io/ipfs/";
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _catIdCounter.current();
        _catIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // function safeMint(
    //     string memory _uri,
    //     address to,
    //     string memory _name,
    //     string memory _color,
    //     string memory _fluffLevel,
    //     uint8 _age
    // ) public onlyOwner {
    //     Cat memory _cats = Cat(_uri, _name, _color, _fluffLevel, _age);
    //     uint256 tokenId = cats.push(_cats) - 1;
    //     _safeMint(to, tokenId);
    //     _setTokenURI(tokenId, _uri);
    // }

    // function getCatFromId(uint256 id)
    //     public
    //     view
    //     returns (
    //         string memory,
    //         address,
    //         string memory,
    //         string memory,
    //         string memory,
    //         uint8
    //     )
    // {
    //     return (
    //         cats[id].uri,
    //         cats[id].name,
    //         cats[id].color,
    //         cats[id].fluffLevel,
    //         cats[id].age
    //     );
    // }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}