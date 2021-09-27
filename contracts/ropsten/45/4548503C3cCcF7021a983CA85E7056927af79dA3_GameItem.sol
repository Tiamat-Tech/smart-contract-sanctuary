// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameItem is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    mapping(uint256=>string) tokenUrl;
    
    modifier onlyOwner(){
        require(owner==msg.sender,"Not Owner");
        _;
    }
    
    address public owner ;

    constructor()  ERC721("GameItem", "ITM") {
        owner = msg.sender;
    }

    function awardItem(address player, uint256 tokenId,string memory tokenURI)
        public payable 
        returns (uint256)
    {
        
        _mint(player, tokenId);
        tokenUrl[tokenId] = tokenURI;
        (bool success, bytes memory data) = owner.call{value:msg.value}("");
        require(success==true,"Payment not done");
        return tokenId;
    }
    
    function checkToken(uint256 tokenId) public view returns(string memory){
        return(tokenUrl[tokenId]);
    }
    
    function changeOwner(address _newowner) public onlyOwner{
        owner = _newowner;
    }

}