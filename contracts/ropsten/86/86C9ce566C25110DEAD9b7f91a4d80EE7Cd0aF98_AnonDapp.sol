// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AnonDapp is ERC721, Ownable {
    

  uint256 public maxSupply;
  uint256 public cost;
  uint256 public maxMintPerWalletAddress;
  bool public paused;
  string public baseExtension;
  string public baseURI;
  
  constructor(string memory _name, string memory _symbol, string memory _initialBaseURI) ERC721(_name, _symbol) {
      setBaseURI(_initialBaseURI);

  }
  
  mapping(address => uint256) public addressToMintBalance;
  

  function getCost() public view returns (uint256) {
      return cost;
  }

  function setCost(uint256 _cost) public onlyOwner {
      cost = _cost;
  }
  
  function setMaxSuply(uint256 _maxSupply) public onlyOwner {
      maxSupply = _maxSupply;
  }
  
  function getMaxSupply() public view returns (uint256) {
      return maxSupply;
  }
  
  function togglePaused() public onlyOwner returns (bool) {
      paused = !paused;
      return true;
  }
  
  function getStatus() public view returns (bool) {
      return paused;
  }
  
  function setBaseExtension(string memory _baseExtension) public onlyOwner {
      baseExtension = _baseExtension;
  }
  
  function getBaseURI() public view returns (string memory) {
    return baseURI;
  }
  
   function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }
  
   function withdraw() public payable onlyOwner {
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(success);
  }
  
  function setMaxMintPerWalletAddress(uint256 _maxMintPerWalletAddress) public onlyOwner {
      maxMintPerWalletAddress = _maxMintPerWalletAddress;
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
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory base = _baseURI();
    return bytes(base).length > 0
        ? string(abi.encodePacked(base, tokenId, baseExtension))
        : "";
  }


  function mint(uint256 _amount, uint256 tokenId) public payable {
    require(!paused, "Contract is currently paused");
    require(_amount > 0, "Inavalid Input, Must mint at least 1 NFT");
    require(_amount <= maxMintPerWalletAddress, "maxMintPerWalletAddress Exceeded");
    require(addressToMintBalance[msg.sender] + _amount < maxMintPerWalletAddress, "All NFTs are Minted");
    require(addressToMintBalance[msg.sender] + _amount < maxSupply, "All NFTs are Minted");
    require(msg.value >= cost * _amount, "Cannot Complete, Insufficient Funds");

    if (msg.sender != owner()) {
        _safeMint(msg.sender, tokenId);
        addressToMintBalance[msg.sender] ++;
        setApprovalForAll(msg.sender, true);
    }
    
    _safeMint(msg.sender, tokenId);
   
  }
  
  
  
}