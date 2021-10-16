// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/security/Pausable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";


contract Yamsteers is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIdCounter;

    string baseURI;
    uint256 public cost = 0.02 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmount = 10;

    constructor() ERC721("Yamsteers", "YAM") {}

    function _baseURI() internal pure override returns (string memory) {
        return "none";
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    // jhlkjlkjkl
    
    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner() {
    maxMintAmount = _newmaxMintAmount;
    }
  
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;                                          // Boring apes = function setBaseURI(string memory baseURI) public onlyOwner {setBaseURI(baseURI);
    }

  
    function withdraw() public payable onlyOwner {
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(success);
    }
      // test zatial
    function mint(uint256 _mintAmount) public whenNotPaused payable {
    uint256 supply = totalSupply();
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount);
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }
}

//functions to consider 
        //boring apes mint {without constructing json}
        // for(uint i = 0; i < numberOfTokens; i++) {
        //     uint mintIndex = totalSupply();
        //     if (totalSupply() < MAX_APES) {
        //         _safeMint(msg.sender, mintIndex);
        //     }
        // }