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
       uint256 timeLock;
        
        
    }
    uint256 newId = 0;
    address payable store = payable(address(this));

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

    function createBackedItem(string memory uri) public  granted {
       

       uint256 Id = newId;
        uint256 backedETH = 0;
        uint256 backedUSD = 0;
        uint256 timeLock = block.timestamp + 90 days;
       
        

        artworks.push(
            Art(
                Id,
                backedETH,
               backedUSD,
               timeLock
                
            )
        );
        
        
        uint256 tokenId = _tokenIdCounter.current();
        
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        newId++;
    }

    function backNFT(uint256 tokenId, uint256 backedAmount) public payable {
        require(msg.sender == ownerOf(tokenId));
        require(msg.value >= backedAmount);
        artworks[tokenId].backedETH = backedAmount;
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