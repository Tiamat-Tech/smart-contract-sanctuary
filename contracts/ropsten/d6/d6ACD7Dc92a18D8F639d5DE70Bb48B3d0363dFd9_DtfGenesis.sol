// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/*
 * @title ERC721 token for DAOTaiFung genesis collection

    8888888b.        d8888  .d88888b. 88888888888       d8b 8888888888                         
    888  "Y88b      d88888 d88P" "Y88b    888           Y8P 888                                
    888    888     d88P888 888     888    888               888                                
    888    888    d88P 888 888     888    888   8888b.  888 8888888 888  888 88888b.   .d88b.  
    888    888   d88P  888 888     888    888      "88b 888 888     888  888 888 "88b d88P"88b 
    888    888  d88P   888 888     888    888  .d888888 888 888     888  888 888  888 888  888 
    888  .d88P d8888888888 Y88b. .d88P    888  888  888 888 888     Y88b 888 888  888 Y88b 888 
    8888888P" d88P     888  "Y88888P"     888  "Y888888 888 888      "Y88888 888  888  "Y88888 
                                                                                        888 
                                                                                    Y8b d88P 
                                                                                    "Y88P"  
    .d8888b.                                      d8b                                         
    d88P  Y88b                                     Y8P                                         
    888    888                                                                                 
    888         .d88b.  88888b.   .d88b.  .d8888b  888 .d8888b                                 
    888  88888 d8P  Y8b 888 "88b d8P  Y8b 88K      888 88K                                     
    888    888 88888888 888  888 88888888 "Y8888b. 888 "Y8888b.                                
    Y88b  d88P Y8b.     888  888 Y8b.          X88 888      X88                                
    "Y8888P88  "Y8888  888  888  "Y8888   88888P' 888  88888P'                                
                                                                     
 */
contract DtfGenesis is ERC721, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenSupply;

  string baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.088 ether;
  uint256 public maxSupply = 888;

  // Each address can only mint at most 1 token
  uint256 public maxMintAmount = 1;

  bool public paused = false;
  bool public revealed = false;
  string public notRevealedUri;

  bytes32 public mintMerkleRoot;

  // Mapping from address to the amount of tokens that the address has minted
  mapping(address => uint256) public mintTxs;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _initNotRevealedUri
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
    setNotRevealedURI(_initNotRevealedUri);
  }

  modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
      require(
          MerkleProof.verify(
              merkleProof,
              root,
              keccak256(abi.encodePacked(msg.sender))
          ),
          "Address is not in the allowlist"
      );
      _;
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function mint(uint256 _mintAmount, bytes32[] calldata merkleProof)
    external
    payable
    isValidMerkleProof(merkleProof, mintMerkleRoot)
{
    uint256 supply = _tokenSupply.current();
    require(!paused, "Minting paused");
    require(_mintAmount > 0, "_mintAmount cannot be less than or equal to 0");
    require(_mintAmount <= maxMintAmount, "Attempting to mint too many NFTs");
    require(mintTxs[msg.sender] < maxMintAmount, "Can only mint at most 1 NFT per address");
    require(supply + _mintAmount <= maxSupply, "All NFTs have been minted");

    if (msg.sender != owner()) {
      require(msg.value >= cost * _mintAmount, "Not enough ETH to mint the NFT");
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      mintTxs[msg.sender] += 1;
      _tokenSupply.increment();
      _safeMint(msg.sender, supply + i);
    }
  }

  function totalSupply()
    external
    view
    returns (uint256)
  {
    return _tokenSupply.current();
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
    
    if(revealed == false) {
        return notRevealedUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only owner
  function reveal() public onlyOwner {
      revealed = true;
  }
  
  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
    maxMintAmount = _newmaxMintAmount;
  }
  
  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedUri = _notRevealedURI;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function setMintMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
      mintMerkleRoot = _merkleRoot;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
 
  function withdraw() public payable onlyOwner {
    // This will payout the owner 95% of the contract balance.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    // =============================================================================
  }
}