pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
//mport "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract APNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("APNFT", "APNFT") {}

    struct Art {
        uint256 Id;
        uint256 backedETH;
        uint256 backedUSD;
       // uint256 wisdom;
        
        
    }

    Art[] public artworks;
    
     mapping (address => bool) public  isAllowed;
     
      modifier granted(){
        require(msg.sender == owner() || isAllowed[msg.sender]);
        _;

      }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function createBackedItem(uint256 backedAmount, string memory uri) public payable granted {
        uint256 backedValue = backedAmount * 1 ether;
        
        require(msg.value >= backedValue);
        uint256 tokenId = _tokenIdCounter.current();
        artworks[tokenId].Id = tokenId;
        artworks[tokenId].backedETH = backedAmount;
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }

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
        return super.tokenURI(tokenId);
    }
    
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public granted{
        //require(
        //    _isApprovedOrOwner(_msgSender(), tokenId),
       //     "ERC721: transfer caller is not owner nor approved"
       // );

      
        _setTokenURI(tokenId, _tokenURI);
    }
    
    function toggleAllowed(address addr) external onlyOwner {
        isAllowed[addr] = !isAllowed[addr];
    }
    

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}