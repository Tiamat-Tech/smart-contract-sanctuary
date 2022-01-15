// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract xxzzyy is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    uint256 public maxSupply = 10000;
    constructor() ERC721("xxzzyy", "xzy") {}

    function _baseURI() internal pure override returns (string memory) {
        return "YOUR_API_URL/api/erc721/";
    }
  
  function tokensOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);

    

    

      for(uint256 ownedTokenIndex = 0;ownedTokenIndex < ownerTokenCount; ownedTokenIndex++ ){
           
         ownedTokenIds[ownedTokenIndex] = tokenOfOwnerByIndex(_owner,ownedTokenIndex);

      }
     

     


    return ownedTokenIds;
  }




    function mint(address to)
        public returns (uint256)
    {
        require(_tokenIdCounter.current() < 10000); 

         for (uint256 i = 1; i <= 20; i++) {
            _safeMint(to, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
        
      

        return _tokenIdCounter.current();
    }
}