pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./random/RandomlyAssigned.sol";

contract X200 is ERC721, Ownable, RandomlyAssigned, ReentrancyGuard, Pausable {
  using Strings for uint256;

  event mintedId(uint256 message);
  // uint256 public requested;
  uint256 public currentSupply = 0;
  //TODO: Confirm this cannot be changed by users (is public)
  uint256 public maxMint = 20; 
  uint256 public price = 0.02 ether; // Each DarkSide cost 0.05 ETH to mint
  
  // Max. 10000 NFTs available; Start counting from 1 (instead of 0)
  constructor() 
    ERC721("X200", "DS")
    RandomlyAssigned(10000,1)
    {
      for (uint256 a = 1; a <= 50; a++) {
            //mint(msg.sender);
            mint(1);
      }

      // Transactions are paused after deploy
      pause();
    }

  string public baseURI = "https://nft.worldmetro.io/";

  function _setBaseURI(string memory _uri) public onlyOwner {
    baseURI = _uri;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

    //function mint (address _to)    
  function mint (uint256 _quantity)
      public
      payable
      nonReentrant
  {
      //require( tokenCount() + 1 <= totalSupply(), "YOU CAN'T MINT MORE THAN MAXIMUM SUPPLY");
      require( tokenCount() + _quantity <= totalSupply(), "YOU CAN'T MINT MORE THAN MAXIMUM SUPPLY");
      // require( availableTokenCount() - 1 >= 0, "YOU CAN'T MINT MORE THAN AVALABLE TOKEN COUNT"); 
      require( availableTokenCount() - _quantity >= 0, "YOU CAN'T MINT MORE THAN AVALABLE TOKEN COUNT");
      require( tx.origin == msg.sender, "CANNOT MINT THROUGH A CUSTOM CONTRACT");

      if(msg.sender == owner()){  
          
          if (msg.sender != owner()) {  
            require( msg.value >= price * _quantity, "Ether sent is not correct");

            require( balanceOf(msg.sender) <= 3);
          }
      }
      
      //This wil give us a random number that hasn't been used before
      //We use that to mint the tokenCount
        //But we can also ignore the ID and insert our specific id
        //That number will remain available 

      for (uint256 i = 1; i <= _quantity ; i++) {

        uint256 id = nextToken();
        //_safeMint(_to, id);
        _safeMint(msg.sender, id);
        currentSupply++;
        emit mintedId(id);
      }

  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistant token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), ".json"))
        : "";
  }

  function isAvailable(uint tokenId) public view returns(address){

      require( availableTokenCount() - 1 >= 0, "YOU CAN'T MINT MORE THAN AVALABLE TOKEN COUNT"); 

      address owner = ownerOf(tokenId);

      return owner;
  }
  
  function withdraw() public payable onlyOwner {
    require(payable(msg.sender).send(address(this).balance));
  }

  function pause() public onlyOwner {
    _pause();
  }

  function start() public onlyOwner {
    _unpause();
  }

  function setPrice(uint256 _price) public onlyOwner() {
    price = _price;
  }

  function setMaxMint(uint256 _maxMint) public onlyOwner() {
    maxMint = _maxMint;
  }

 
}