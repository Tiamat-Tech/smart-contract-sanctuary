//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Scanderbeg is ERC721{
    mapping (uint256 => string) private _tokenURIs;
    uint256 public tokenCounter;

    constructor(string memory name, string memory symbol) ERC721(name, symbol){
        tokenCounter = 0;
    }
    
    function mint(string memory _tokenURI) public {
        _safeMint(msg.sender, tokenCounter);
        _setTokenURI(_tokenURI, tokenCounter);

        tokenCounter++;
    }

    function _setTokenURI(string memory _tokenURI, uint256 _tokenID) internal virtual{
        require(_exists(_tokenID), "Token does not exist");
        _tokenURIs[_tokenID] = _tokenURI;
    }

    function tokenURI(uint256 _tokenID) public view virtual override  returns (string memory){
        require(_exists(_tokenID), "Token does not exist");
        return _tokenURIs[_tokenID];
    }

}