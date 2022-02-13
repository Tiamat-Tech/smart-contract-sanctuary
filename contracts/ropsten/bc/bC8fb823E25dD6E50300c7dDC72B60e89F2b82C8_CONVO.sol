// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CONVO is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;
    
    constructor() ERC721("CONVO Tutorial", "CONVO") {}
    
    function mintTo(address recipient)
        public
        returns (uint256)
    {
        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        return newItemId;
    }

      /// @dev Returns an URI for a given token ID
  function _baseURI() internal view virtual override returns (string memory) {
    return "https://arweave.net/93nTEsTTXw4JXVw2QI1yKjCwZLcVpJyojcfeoWQLMlM/";
  }
}