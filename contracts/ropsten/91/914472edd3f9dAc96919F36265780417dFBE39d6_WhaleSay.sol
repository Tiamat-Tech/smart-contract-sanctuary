// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WhaleSay is ERC721, Ownable {
    string public baseURI;
    uint256 public _totalSupply;

    constructor() ERC721("MyToken", "MTK") {
        baseURI = string("ipfs://QmdW2avchFGmRpmPknMmM44o2B5HLtZAEXEGe1XGqh5Tvc/");
        _totalSupply = 2553;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);       
    }

    function batchMint(address[] memory addresses, uint256 start) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            _safeMint(addresses[i], start+i);
        }
    }
}