//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FonzyTest is ERC721Enumerable, Ownable {
    string private message;
    
    constructor() ERC721("FonzyTest", "FT"){
        message = "";
    }

    function updateMessage(string memory _message) public onlyOwner {
        message = _message;
    }

    function getMessage() public view returns (string memory) {
        return message;
    }
}