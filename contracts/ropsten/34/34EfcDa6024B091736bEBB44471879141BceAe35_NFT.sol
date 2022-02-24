// SPDX-License-Identifier: GPL-3.0

// Created by NAJI


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Contract: DeStorm
// Author: NAJI
// ---- CONTRACT BEGINS HERE ----

pragma solidity ^0.8.0;

contract NFT is ERC721Enumerable, Ownable {
  using Strings for uint256;

  string public baseURI;
  string public baseExtension = ".json";
  uint256 public maxSupply = 666;
  bool public paused = false;
  
  // Wallet Address for widthdraw
  address public BlockchainAddress = 0x7AdE7e7e26B6cCf64BbEFa6a7e93482Ae7a972D4; // should be updated
  address public NFTBrandAddress = 0xE19aBD85A10Aa5321796506c2A80c3BC35eD8B00; // should be updated

  // Percent for widthdraw
  uint public BlockchainPercent = 80;
  uint public NFTBrandAddressPercent = 20;

  // Price of NFT
  uint256 public presalePrice = 0.01 ether;
  uint256 public publicPrice =  0.02 ether;
  uint256 public highPrice =  0.03 ether;
  // Number of Mint Count
  uint256 public presaleCount = 100;
  uint256 public publicCount =  250;
  uint256 public highCount =  666;

  // Real Sell Date
  uint256 public maxMintAmount = 5;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function mint(address _to, uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    require(!paused);
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);
    

    if( supply + _mintAmount < presaleCount ) {
      require(msg.value >= presalePrice * _mintAmount );
    }
    else if ( supply + _mintAmount < publicCount ) {
      require(msg.value >= publicPrice * _mintAmount );
    }
    else {
      require(msg.value >= highPrice * _mintAmount);
    }
    
    // Mint NFT
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(_to, supply + i);
    }

    // Withdwraw
    withdrawToTwoAddress();
  }
  
  // public
  function giveAwayMint(address _to) public onlyOwner {
    uint256 supply = totalSupply();   
    require(supply < maxSupply);
    _safeMint(_to, supply + 1);
  }
  // Widthdraw Money to Two wallet
  function withdrawToTwoAddress() public payable {
    // Widthdraw money to Blackchain Wallet
    require(payable(BlockchainAddress).send(msg.value * BlockchainPercent / 100));
    // Widthdraw money to NFT Brand Wallet
    require(payable(NFTBrandAddress).send(msg.value * NFTBrandAddressPercent / 100));
  }
  
  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent NFT"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }



 //
 // ONLY THE OWNER CAN CALL THE FUNCTIONS BELOW.
 //
  
 // This sets the minting presale price of each NFT.
 // Example: If you pass in 0.2, then you will need to pay 0.2 ETH + gas to mint 1 NFT.
  function setPresalePrice(uint256 _newCost) public onlyOwner() {
    presalePrice = _newCost;
  }
 // This sets the minting price of each NFT.
 // Example: If you pass in 0.1, then you will need to pay 0.1 ETH + gas to mint 1 NFT.
  function setPublicPrice(uint256 _newCost) public onlyOwner() {
    publicPrice = _newCost;
  }
 // This sets the minting presale price of each NFT.
 // Example: If you pass in 0.2, then you will need to pay 0.2 ETH + gas to mint 1 NFT.
  function sethighPrice(uint256 _newCost) public onlyOwner() {
    highPrice = _newCost;
  }
  // This sets Address of Blockchain Address.
  function setBlockchainAddress(address _newAddress) public onlyOwner() {
    BlockchainAddress = _newAddress;
  }
  // This sets Address of BrandNFT Address.
  function setNFTBrandAddress(address _newAddress) public onlyOwner() {
    NFTBrandAddress = _newAddress;
  }
  
  
 
 // This sets the max supply. This will be set to 10,000 by default, although it is changable.
  function setMaxSupply(uint256 _newSupply) public onlyOwner() {
    maxSupply = _newSupply;
  }
  
 // This changes the baseURI.
 // Example: If you pass in "https://google.com/", then every new NFT that is minted
 // will have a URI corresponding to the baseURI you passed in.
 // The first NFT you mint would have a URI of "https://google.com/1",
 // The second NFT you mint would have a URI of "https://google.com/2", etc.
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

 // This sets the baseURI extension.
 // Example: If your database requires that the URI of each NFT
 // must have a .json at the end of the URI 
 // (like https://google.com/1.json instead of just https://google.com/1)
 // then you can use this function to set the base extension.
 // For the above example, you would pass in ".json" to add the .json extension.
  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

 // This pauses or unpauses sales.
  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
 
 // This withdraws the contract's balance of ETH to the Owner's (whoever launched the contract) address.
  function withdraw() public payable onlyOwner {
    require(payable(msg.sender).send(address(this).balance));
  }
  

}