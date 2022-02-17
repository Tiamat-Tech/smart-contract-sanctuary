// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Import the openzepplin contracts
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Newcontract is ERC721, ERC721URIStorage {

    constructor() ERC721("Newtoken", "NewTok") {

      _createToken(msg.sender, 1, "QmPctf8hmNNk1yxcMEYN9K7Bi35uZeYJeHQCZ2SE8f12GY");

    }

    function _createToken(address to, uint id, string memory url) private returns (bool) {
      _safeMint(to, id);
      _setTokenURI(id, url);
      return true;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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