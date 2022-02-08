//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";   // 基本ERC721 class
import "@openzeppelin/contracts/utils/Counters.sol";        // 計數器2 當作 NFT ID使用
import "@openzeppelin/contracts/access/Ownable.sol";        // 擁有者
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract EvanNFT is ERC721URIStorage {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    
    // token name, 縮寫
    constructor() ERC721("EvanFirstNFT", "EVANFRIRSTNFT") {} 

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}