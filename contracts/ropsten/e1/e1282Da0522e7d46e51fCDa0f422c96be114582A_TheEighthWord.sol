// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";

// The most basic NFT contract ever. This must be so easy!
contract TheEighthWord is ERC721, Ownable {
    constructor() ERC721("TheEighthWord", "SEED8 ") {}
    
    string public URI = "";

    // This next puzzle is inter-planetary
    function _baseURI() internal view override returns (string memory) {
        return URI;
    }
    
    function setURI(string memory _URI) public onlyOwner {
        URI = _URI;
    }

    function safeMint(uint256 tokenId) public {
        _safeMint(msg.sender, tokenId);
    }
}
// After you get the 8th word... Your journey continues here: https://github.com/mallorythedeveloper/solidity-tips