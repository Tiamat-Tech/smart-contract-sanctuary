//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Watch is ERC721 {
  
  uint256 public tokenCounter;
  mapping (uint256 =>  string) private _tokenURIs;
  
  constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
      tokenCounter = 0;
    }

    function mint(string memory _tokenURI) public {
      _safeMint(msg.sender, tokenCounter);
      _setTokenURI(tokenCounter, _tokenURI);

      tokenCounter++;
    }

    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal virtual {
      require(
        _exists(_tokenId),
        "URI set of nonexistent token"
      );
      _tokenURIs[_tokenId] = _tokenURI;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns(string memory) {
      require(
        _exists(_tokenId),
        "URI get of nonexistent token"
      );

      return _tokenURIs[_tokenId];
    }
}