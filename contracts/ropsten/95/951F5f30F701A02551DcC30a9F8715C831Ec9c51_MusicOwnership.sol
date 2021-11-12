// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

 contract MusicOwnership is ERC721, Ownable {
        
    using Strings for uint256;

    mapping (uint256 => string) private _tokenURIs;
    string private _baseURIextended;

    constructor(string memory _name, string memory _symbol)
    ERC721(_name, _symbol)
    {}
  
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
    require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
    
    _tokenURIs[tokenId] = _tokenURI;
    }
        
    function mint(address reciever, string memory tokenURI_,uint256 tokenId) external {
        uint256 newNftTokenId = tokenId;
        require((_exists(tokenId) == false),"This Id has already been used");
        _mint(reciever, newNftTokenId);
        _setTokenURI(newNftTokenId, tokenURI_);
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
            string memory base = "https://ipfs.io/ipfs/";
            
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        return string(abi.encodePacked(base, tokenId.toString()));
    }
        
    function transfer(address reciever, address sender, uint256 tokenId) external {
        require(_exists(tokenId), "This token does not exist");
        transferFrom(sender,reciever,tokenId);
        approve(reciever,tokenId);
    }
}