pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract TestNFT is ERC721, Ownable {

  uint256 private tokenCounter;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}   


  function _baseURI() internal view override returns (string memory) {
      return "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/";
  }

  function mint() public {
      _safeMint(msg.sender, tokenCounter);
      tokenCounter++;
    }
}