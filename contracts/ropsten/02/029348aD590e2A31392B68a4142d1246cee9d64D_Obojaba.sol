//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Obojaba is ERC721 {

    uint256 public tokenCounter;
    string private _baseURIextended;

    mapping (uint256 => string) private _tokenURIs;

    constructor() ERC721("OBOJAMA","OBJ"){
    }
    function createCollectible() public {
        address dogOwner = msg.sender;
        uint256 newItemId = tokenCounter;
        _safeMint(dogOwner, newItemId);
    }

    function baseTokenURI() public pure returns (string memory){
        return "https://asia-northeast1-sekai420.cloudfunctions.net/nft-metadata";
    }
    // function setBaseURI() external {
    //     _baseURIextended = "https://asia-northeast1-sekai420.cloudfunctions.net/nft-metadata";
    // }

    // function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
    //     require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
    //     _tokenURIs[tokenId] = _tokenURI;
    // }
    
}