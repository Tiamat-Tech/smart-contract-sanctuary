// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Yamsteers2 is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant PREMINTER_ROLE = keccak256("PREMINTER_ROLE");
    //bytes32 public constant PREMINTER_ROLE = keccak256("TEAM_ROLE");

    Counters.Counter private _tokenIdCounter;

    string baseURI;
    uint256 public cost = 0.0001 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmount = 10;
    uint256 public preSaleMaxMintAmount = 2;
    bool public preSale = false;
    bool public revealed = false;
    // uint256 public teamReserve = 5; 

    constructor(
        string memory _initBaseURI
        )
    ERC721("Yamsteers2", "YML") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PREMINTER_ROLE, msg.sender);
        setBaseURI(_initBaseURI);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

 /*   function safeMint(address to) public onlyRole(MINTER_ROLE) {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }
*/
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        require(
          _exists(tokenId),
          "ERC721Metadata: URI query for nonexistent token"
        );
        
        if(revealed == false) {
            return _baseURI();
        }
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        
        return super.supportsInterface(interfaceId);
    }
    
    //external methods
    
    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyRole(DEFAULT_ADMIN_ROLE) {
    maxMintAmount = _newmaxMintAmount;
    }
  
    function setBaseURI(string memory _newBaseURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _newBaseURI;                                         
    }
    
    function preSaleSwitch() public onlyRole(DEFAULT_ADMIN_ROLE) {
        preSale = !preSale;                                         
    }
  
    function withdraw() public payable onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
    
      // test zatial
    function mint(uint256 _mintAmount) public whenNotPaused payable {
        uint256 supply = totalSupply();
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount);
        require(supply + _mintAmount <= maxSupply);
        require(msg.value >= cost * _mintAmount);
    
        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
    }
    
    function preSaleMint(uint256 _mintAmount) public payable onlyRole(PREMINTER_ROLE) {
        require(preSale);
        uint256 supply = totalSupply();
        require(_mintAmount > 0);
        require(_mintAmount <= preSaleMaxMintAmount);
        require(supply + _mintAmount <= maxSupply);
        require(msg.value == cost * _mintAmount);
    
        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
    }
    
    //TODO: team-mint method
}