// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract VolcanoNFT is ERC721, Ownable {
   
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    
    constructor() ERC721('VolcanoNFT', 'VOLN') {
    }
    
    struct metaData {
        uint timestamp;
        uint256 tokenId;
        string tokenURI;
    }
    
    mapping(address => metaData[]) public ownedNFT;
    
    string private baseTokenURI;
    uint[] public test;
    
    function mint(address to) public onlyOwner {
        tokenIds.increment();
        
        uint256 newTokenId = tokenIds.current();
        _safeMint(to, newTokenId);
        
        string memory newTokenURI = ERC721.tokenURI(newTokenId);
        metaData memory newTokenData = metaData(block.timestamp, newTokenId, newTokenURI);
        ownedNFT[to].push(newTokenData);
    }
    
    function burn(uint _tokenId) public returns(bool) {
        require(msg.sender == ERC721.ownerOf(_tokenId), "you don't own this NFT");
        
        metaData[] storage newOwnedNFT = ownedNFT[msg.sender];
        uint length = newOwnedNFT.length;
        
        for(uint i = 0; i <= length; i++) {
            if (newOwnedNFT[i].tokenId == _tokenId) {
                newOwnedNFT[i] = newOwnedNFT[length - 1];
                newOwnedNFT.pop();
            }
        }
        
        ERC721._burn(_tokenId);
        return true;
    }
    
    function _setBaseURI(string memory newBaseTokenURI) public onlyOwner {
        baseTokenURI = newBaseTokenURI;
    }

    function _baseURI() override internal view virtual returns (string memory) {
        return baseTokenURI;
    }

    function viewOwnedNFT(address owner) public view returns(metaData[] memory) {
        return(ownedNFT[owner]);
    }
}