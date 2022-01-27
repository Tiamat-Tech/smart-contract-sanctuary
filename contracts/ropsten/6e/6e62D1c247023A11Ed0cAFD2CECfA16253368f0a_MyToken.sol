// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract MyToken is ERC721, Ownable,Mintable {
    using Counters for Counters.Counter;

    string public baseTokenURI;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Rufus", "RF")  Mintable(0xbe5475C0BBC2F06Be89C1bceFE16CD488C5Bd70f, 0x4527BE8f31E2ebFbEF4fCADDb5a17447B27d2aef) {}






    function _baseURI() internal pure override returns (string memory) {
        return "https://4b56907172a9.ngrok.io/";
    }

    

     function setBaseTokenURI(string memory uri) public onlyOwner {
        baseTokenURI = uri;
    }

      function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

       function _mintFor(
        address to,
        uint256 id,
        bytes memory
    ) internal override {
        safeMint(to);
    }


    
}