// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MetalHead is ERC721Enumerable, Ownable {
  using Strings for uint256;
  using ECDSA for bytes32;

  uint256 public constant MH_MAX = 8_888;
  uint256 public constant PRICE = 0.999 ether;

  uint256 private _mhPresaleTotalSupply = 1_000;
  uint256 private _mhPublicSaleTotalSupply = 7_888;

  uint256 public presaleMaxMint = 1;
  uint256 public publicSaleMaxMint = 1;

  bool public isActive = false;
  bool public isPresaleActive = false;
  bool public isPublicSaleActive = false;
  string public proof;

  uint256 public totalPresaleSold;
  uint256 public totalPublicSaleSold;
  uint256 public totalSold;

  mapping(address => bool) private _presaleAllowList;
  mapping(address => uint256) private _presaleAllowListClaimed;
  mapping(string => bool) private _usedNonces;

  bool public isRevealed = false;

  string private _contractURI = '';
  string private _tokenBaseURI = '';
  string private _tokenPlaceholderBaseURI = '';
  address private _signerAddress = 0x8226dadc00979e4F1cF1F9767571A2A7085Ac7Aa;

  constructor() ERC721("MetalHead", "MH") {}
  
  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  function setIsActive(bool _isActive) external onlyOwner {
    isActive = _isActive;
  }

  function setProof(string calldata proofString) external onlyOwner {
    proof = proofString;
  }
  
  function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
    require(_exists(tokenId), 'Token not exist');

    if (!isRevealed) {
      return _tokenPlaceholderBaseURI;
    }

    string memory base = _tokenBaseURI;

    return string(abi.encodePacked(base, tokenId.toString()));
  }

  function setBaseURI(string calldata URI) external onlyOwner {
    _tokenBaseURI = URI;
  }

  function setPlaceholderBaseURI(string calldata placeholderBaseURI) external onlyOwner {
    _tokenPlaceholderBaseURI = placeholderBaseURI;
  }

  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  function setContractURI(string calldata URI) external onlyOwner {
    _contractURI = URI;
  }

  function mhPresaleTotalSupply() public view returns (uint256) {
    return _mhPresaleTotalSupply;
  }

  function setPresaleTotalSupply(uint256 total) external onlyOwner {
    _mhPresaleTotalSupply = total;
  }

  function addToPresaleAllowList(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "Can't add the null address");

      _presaleAllowList[addresses[i]] = true;
      _presaleAllowListClaimed[addresses[i]] > 0 ? _presaleAllowListClaimed[addresses[i]] : 0;
    }
  }

  function isPresaleAllowList(address addr) external view returns (bool) {
    return _presaleAllowList[addr];
  }

  function removeFromPresaleAllowList(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "Can't add the null address");

      _presaleAllowList[addresses[i]] = false;
    }
  }

  function presaleAllowListCountClaimedBy(address owner) external view returns (uint256){
    require(owner != address(0), 'Zero address not in Allow List');

    return _presaleAllowListClaimed[owner];
  }

  function setIsPresaleActive(bool _isPresaleActive) external onlyOwner {
    isPresaleActive = _isPresaleActive;
  }

  function setPresaleMaxMint(uint256 maxMint) external onlyOwner {
    presaleMaxMint = maxMint;
  }

  function presalePurchase(uint256 numberOfTokens) external payable {
    require(isActive, 'Contract inactive');
    require(isPresaleActive, 'Presale inactive');
    require(_presaleAllowList[msg.sender], 'Not in presale allow list');
    require(totalSupply() < MH_MAX, 'All tokens have been minted');
    require(numberOfTokens <= presaleMaxMint, 'Cannot purchase this many tokens');
    require(totalPresaleSold + numberOfTokens <= mhPresaleTotalSupply(), 'Exceed presale total supply');
    require(_presaleAllowListClaimed[msg.sender] + numberOfTokens <= presaleMaxMint, 'Exceed max allowed presale');
    require(PRICE * numberOfTokens <= msg.value, 'ETH insufficient');

    for (uint256 i = 0; i < numberOfTokens; i++) {
      uint256 tokenId = totalSold + 1;

      totalPresaleSold += 1;
      totalSold += 1;
      _presaleAllowListClaimed[msg.sender] += 1;
      _safeMint(msg.sender, tokenId);
    }
  }

  function mhPublicSaleTotalSupply() public view returns (uint256) {
    return _mhPublicSaleTotalSupply;
  }

  function setPublicSaleTotalSupply(uint256 total) external onlyOwner {
    _mhPublicSaleTotalSupply = total;
  }

  function setIsPublicSaleActive(bool _isPublicSaleActive) external onlyOwner {
    isPublicSaleActive = _isPublicSaleActive;
  }

  function setPublicSaleMaxMint(uint256 maxMint) external onlyOwner {
    publicSaleMaxMint = maxMint;
  }

  function publicSalePurchase(bytes32 hash, bytes memory signature, string memory nonce, uint256 numberOfTokens) external payable {
    require(isActive, 'Contract inactive');
    require(isPublicSaleActive, 'Public Sale inactive');
    require(matchAddresSigner(hash, signature), "Signer address not match");
    require(!_usedNonces[nonce], "Hash used");
    require(hashTransaction(msg.sender, numberOfTokens, nonce) == hash, "Hash failed");
    require(totalSupply() < MH_MAX, 'All tokens have been minted');
    require(numberOfTokens <= publicSaleMaxMint, 'Cannot purchase this many tokens');
    require(totalPublicSaleSold + numberOfTokens <= mhPublicSaleTotalSupply(), 'Exceed public sale total supply');
    require(PRICE * numberOfTokens <= msg.value, 'ETH insufficient');

    for (uint256 i = 0; i < numberOfTokens; i++) {
      uint256 tokenId = totalSold + 1;

      totalPublicSaleSold += 1;
      totalSold += 1;
      _safeMint(msg.sender, tokenId);
    }

    _usedNonces[nonce] = true;
  }

  function setSignerAddress(address addr) external onlyOwner {
    _signerAddress = addr;
  }

  function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
    return _signerAddress == hash.recover(signature);
  }

  function hashTransaction(address sender, uint256 qty, string memory nonce) private pure returns(bytes32) {
    bytes32 hash = keccak256(abi.encodePacked(
      "\x19Ethereum Signed Message:\n32",
      keccak256(abi.encodePacked(sender, qty, nonce)))
    );
        
    return hash;
  }
}