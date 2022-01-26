//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract FakeCM is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    using SafeMath for uint256;

    /* Contract param */
    uint256 public MAX_TOKEN=10000; 
    uint256 public startIndex = 0;
        
  

    constructor() public ERC721("FakeCM", "FCM") {
       
    }

    /**
    * Mints token
    */
    function mintToken(uint[] memory tokenIds) public  {
        
        require(tokenIds.length>0,"Must mint at least one token");     
        for(uint i = 0; i < tokenIds.length; i++) {
                require(tokenIds[i] >= 0, "Requested TokenId is above lower bound");
                require(tokenIds[i] < startIndex + MAX_TOKEN,"Requested TokenId is below upper bound"); 
                require(!_exists(tokenIds[i]) ,"tokenId already minted");
        }

        for(uint i = 0; i < tokenIds.length; i++) {
                 _safeMint(msg.sender, tokenIds[i]);
        }

     }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

}