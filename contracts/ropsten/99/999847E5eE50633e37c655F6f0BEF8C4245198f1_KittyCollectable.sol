// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract KittyCollectable is ERC1155, Ownable{
    mapping(address => bool) private _isAuthor;
    modifier onlyAuthors(){
        require(_isAuthor[msg.sender], "only authors can call this function");
        _;
    }
    constructor(
        string memory name
        
        ) 
        ERC1155(name){
            _mint(msg.sender, 0, 1, "");
            _setURI("https://en.wikipedia.org/wiki/Google_Chrome#/media/File:Google_Chrome_icon_(September_2014).svg");
            _isAuthor[msg.sender]=true;
        }
}