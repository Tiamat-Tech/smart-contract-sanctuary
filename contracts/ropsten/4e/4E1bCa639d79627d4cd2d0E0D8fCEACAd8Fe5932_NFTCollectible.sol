//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract NFTCollectible is ERC721Enumerable, Ownable {
  using SafeMath for uint256;
  using Counters for Counters.Counter;
    
  Counters.Counter private _tokenIds;

  bool public paused = true;
  bool public revealed = false;

  uint public constant MAX_SUPPLY = 100;
  uint public constant PRICE = 0.01 ether;
  uint public constant MAX_PER_MINT = 5;

  string public baseTokenURI;

  bytes32 public merkleRoot;

  mapping(address => bool) public whitelistClaimed;
  

  constructor(string memory baseURI) public ERC721("NFT Collectible", "NFTC") {
    setBaseURI(baseURI);
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function reserveNFTs() public onlyOwner {
    uint totalMinted = _tokenIds.current();
    require(
	    totalMinted.add(10) < MAX_SUPPLY, "Not enough NFTs"
    );
    
    for (uint i = 0; i < 10; i++) {
      _mintSingleNFT();
    }
  }

  // pause the sale
  function setPaused(bool _state) public onlyOwner {
    paused = _state;
  }

  // reveal the sale
  function setRevealed(bool _state) public onlyOwner {
    revealed = _state;
  }

  // Mint NFTs (public)
  function mintNFTs(uint _count) public payable {
    uint totalMinted = _tokenIds.current();

    require(!paused, "Sale is paused");
    require(revealed, "Public minting is not available now");
    require(totalMinted.add(_count) <= MAX_SUPPLY, "Not enough NFTs left!");
    require(_count > 0 && _count <= MAX_PER_MINT, "Cannot mint specified number of NFTs.");
    require(msg.value >= PRICE.mul(_count), "Not enough ether to purchase NFTs.");

    for (uint i = 0; i < _count; i++) {
      _mintSingleNFT();
    }
  }

  // Mint NFTs (whitelist)
  function whitelistMintNFTs(bytes32[] calldata _merkleProof, uint _count) public payable {
    uint totalMinted = _tokenIds.current();

    require(!paused, "Sale is paused");
    require(totalMinted.add(_count) <= MAX_SUPPLY, "Not enough NFTs left!");
    require(_count > 0 && _count <= MAX_PER_MINT, "Cannot mint specified number of NFTs.");
    require(msg.value >= PRICE.mul(_count), "Not enough ether to purchase NFTs.");

    require(!whitelistClaimed[msg.sender], "Address had already claimed.");
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof.");

    for (uint i = 0; i < _count; i++) {
      _mintSingleNFT();
    }

    whitelistClaimed[msg.sender] = true;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function setBaseURI(string memory _baseTokenURI) public onlyOwner {
    baseTokenURI = _baseTokenURI;
  }

  function _mintSingleNFT() private {
    uint256 newTokenId = _tokenIds.current();
    _safeMint(msg.sender, newTokenId);
    _tokenIds.increment();
  }

  function tokensOfOwner(address _owner) external view returns (uint[] memory) {
    uint tokenCount = balanceOf(_owner);
    uint[] memory tokensId = new uint256[](tokenCount);

    for (uint i = 0; i < tokenCount; i++) {
      tokensId[i] = tokenOfOwnerByIndex(_owner, i);
    }
     
    return tokensId;
  }

  function withdraw() public payable onlyOwner {
    uint balance = address(this).balance;
    require(balance > 0, "No ether left to withdraw");
    (bool success, ) = (msg.sender).call{value: balance}("");
    require(success, "Transfer failed.");
  }
}