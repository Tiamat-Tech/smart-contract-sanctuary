// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Sapien is ERC721URIStorage, Ownable{
    
    // keep track of total number of NFTs alloted
    uint256 public supply = 2000;
    uint256 public tokenCount;
    uint256 private _sapienPrice = 100000000000000000;
    bool private active;
    string public baseURI;
    
    constructor(string memory _name, string memory _symbol, string memory _baseURI) public ERC721(_name, _symbol) {
        baseURI = _baseURI;
    }

    // @recipient: recipient's address
    // @tokenURI: URL to NFT metadata (ie. Pinata)
    // @_tokenId: randomly generated tokenId to attach to metadata
    // this is a payable contract
    function mintSapien(address recipient, string memory tokenURI, uint256 _tokenId) public payable returns(uint256)
    {
        // sale must be active to mint NFTs
        require(active, "Sale is currently inactive");
        // Ether sent must equal the amount of a Sapien
        require(msg.value == _sapienPrice, "Incorrect amount of ether");
        // Each address is allowed one Sapien
        require(getBalance(recipient) == 0, "You cannot mint more than one Sapien");
        // Tokens minted must not exceed the supply of tokens
        require(getTokensMinted() < supply, "All NFTs have been minted");
        
        _safeMint(recipient, _tokenId);
        _setTokenURI(_tokenId, tokenURI);
        tokenCount = tokenCount + 1;

        return _tokenId;
    }
    
    // @_owner: recipient's address
    // @returns: number of tokens currently in wallet
    function getBalance(address _owner) public view returns (uint256){
        return balanceOf(_owner);
    }
    
    // @getTokensMinted: returns the number of NFTs currently minted
    function getTokensMinted() public view returns (uint256){
        return tokenCount;
    }
    
    function tokenExists(uint256 _tokenId) public view returns (bool){
        return _exists(_tokenId);
    }
    
    // @_active: sale boolean
    function setActive(bool _active) public onlyOwner {
        active = _active;
    }

    function getActive() public view returns (bool){
        return active;
    }
}