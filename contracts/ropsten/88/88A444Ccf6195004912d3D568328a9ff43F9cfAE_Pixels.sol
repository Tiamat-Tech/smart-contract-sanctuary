// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Pixels is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Peesss", "Pes") {}

    function _baseURI() internal pure override returns (string memory) {
        return "YOUR_API_URL/api/erc721/";
    }



    function mint(address to)
        public returns (uint256)
    {
        require(_tokenIdCounter.current() < 10000); 

         for (uint256 i = 1; i <= 50; i++) {
            _safeMint(to, _tokenIdCounter.current() + i);
            _tokenIdCounter.increment();
        }
        
      

        return _tokenIdCounter.current();
    }
}