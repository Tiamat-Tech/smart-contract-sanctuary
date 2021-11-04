// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Items is ERC1155,Ownable {
    using Strings for uint256;

    uint256 private constant GOLD = 1;
    uint256 private constant SILVER = 2;
    uint256 private constant THORS_HAMMER = 3;
    uint256 private constant SWORD = 4;
    uint256 private constant SHIELD = 5;
    mapping (uint256 => string) private _uris;

    constructor()
        ERC1155(
            "https://raw.githubusercontent.com/kinguyen198/ERC721/master/items/{id}.json"
        ) 
    {
        _mint(msg.sender, GOLD, 10**18, "");
        _mint(msg.sender, SILVER, 10**27, "");
        _mint(msg.sender, THORS_HAMMER, 1, "");
        _mint(msg.sender, SWORD, 10**9, "");
        _mint(msg.sender, SHIELD, 10**9, "");
    }
    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
    }
    
    function setTokenUri(uint256 tokenId, string memory uri) public onlyOwner {
        require(bytes(_uris[tokenId]).length == 0, "Cannot set uri twice"); 
        _uris[tokenId] = uri; 
    }
    function setURIItems() public onlyOwner{
        for(uint256 i = 1;i <= 5 ; i++){
            setTokenUri(i,string(abi.encodePacked("https://raw.githubusercontent.com/kinguyen198/ERC721/master/items/", i.toString(), ".json")));
        }
    }
}