// SPDX-License-Identifier: MIT


pragma solidity ^0.8.7;

import './ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AvoFrens is ERC721, ReentrancyGuard, Ownable {
  using Strings for uint256;

  uint256 private constant MAX_TOKENS_PURCHASE = 16;
  uint256 private constant MAX_TOKENS_PRESALE = 16;
  uint256 private constant TOKENS_FOR_ONE_FREE = 8;
  uint256 private constant TOKENS_FOR_TEAM = 6;

  // Maximum amount of tokens available
  uint256 public maxTokens = 10000;

  // Amount of ETH required per mint
  uint256 public price  = 60000000000000000; // 0.06 ETH;

  // Contract to recieve ETH raised in sales
  address private vault = 0xB50E039DCC4B6cD3c058DfdEbaa20Af0aDC12604;

  // Control for public sale
  bool public isRevealed = false;

  // Control for public sale
  bool public isActive = false;

  // Control for claim process
  bool public isClaimActive = false;

  // Control for presale
  bool public isPresaleActive = false;

  // Used for verification that an address is included in claim process
  bytes32 public claimMerkleRoot;

  // Used for verification that an address is included in presale
  bytes32 public presaleMerkleRoot;

  // Reference to image and metadata storage
  string private _baseTokenURI;

  // Storage of addresses that have minted with the `claim()` function
  mapping(address => bool) private claimParticipants;

  // Storage of addresses that have minted with the `presale()` function
  mapping(address => bool) private presaleParticipants;

  // Constructor
  constructor()
        ERC721("Avo Frens", "AVF") {
          for(uint256 i=1; i <= TOKENS_FOR_TEAM; i++){
            _safeMint(_msgSender(), i );
          }
  }

  // Override of `_baseURI()` that returns _baseTokenURI
  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

 // Sets `_baseTokenURI` to be returned by `_baseURI()`
  function setBaseURI(string memory baseURI) public onlyOwner {
    _baseTokenURI = baseURI;
  }

  // Sets `isRevealed` to activate specific `tokenURI()`
  function setRevealed(bool _isRevealed) external onlyOwner {
    isRevealed = _isRevealed;
  }

  // Are the tokens revealed
  function _revealed() internal view virtual override returns (bool) {
    return isRevealed;
  }

  // Sets `isActive` to turn on/off minting in `mint()`
  function setActive(bool _isActive) external onlyOwner {
    isActive = _isActive;
  }

  // Sets `isClaimActive` to turn on/off minting in `claim()`
  function setClaimActive(bool _isClaimActive) external onlyOwner {
    isClaimActive = _isClaimActive;
  }

  // Sets `claimMerkleRoot` to be used in `presale()`
  function setClaimMerkleRoot(bytes32 _claimMerkleRoot) external onlyOwner {
    claimMerkleRoot = _claimMerkleRoot;
  }

  // Sets `isPresaleActive` to turn on/off minting in `presale()`
  function setPresaleActive(bool _isPresaleActive) external onlyOwner {
    isPresaleActive = _isPresaleActive;
  }

  // Sets `presaleMerkleRoot` to be used in `presale()`
  function setPresaleMerkleRoot(bytes32 _presaleMerkleRoot) external onlyOwner {
    presaleMerkleRoot = _presaleMerkleRoot;
  }

  // Sets `maxTokens`
  function setMaxTokens(uint256 _maxTokens) public onlyOwner {
    maxTokens = _maxTokens;
  }

  // Sets `price` to be used in `presale()` and `mint()`(called on deployment)
  function setPrice(uint256 _price) public onlyOwner {
    price = _price;
  }

  // Sets `vault` to recieve ETH from sales and used within `withdraw()`
  function setVault(address _vault) external onlyOwner {
    vault = _vault;
  }

  // Minting function used in the claim process (Max 1 per wallet)
  function claim(bytes32[] calldata _merkleProof) external {
    uint256 supply = totalSupply();
    require(isClaimActive, 'Not Active');
    require(supply < maxTokens, 'Supply Denied');
    require(!claimParticipants[_msgSender()], 'Mint Already Claimed');

    bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    require(MerkleProof.verify(_merkleProof, claimMerkleRoot, leaf), 'Proof Invalid');

    _safeMint(_msgSender(), supply + 1);

    claimParticipants[_msgSender()] = true;
  }

  // Minting function used in the presale
  function presale(bytes32[] calldata _merkleProof, uint256 _amount) external payable {
    uint256 supply = totalSupply();

    require(isPresaleActive, 'Not Active');
    require(_amount <= MAX_TOKENS_PRESALE, 'Amount Denied');
    require(supply + _amount <= maxTokens, 'Supply Denied');
    require(!presaleParticipants[_msgSender()], 'Presale Already Claimed');
    require(msg.value >= price * _amount, 'Ether Amount Denied');

    bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    require(MerkleProof.verify(_merkleProof, presaleMerkleRoot, leaf), 'Proof Invalid');

    _amount = _amount + _amount / TOKENS_FOR_ONE_FREE;
    for(uint256 i=1; i <= _amount; i++){
      _safeMint(_msgSender(), supply + i );
    }

    presaleParticipants[_msgSender()] = true;
  }

  // Minting function used in the public sale
  function mint(uint256 _amount) external payable {
    uint256 supply = totalSupply();

    require(isActive, 'Not Active');
    require(_amount <= MAX_TOKENS_PURCHASE, 'Amount Denied');
    require(supply + _amount <= maxTokens, 'Supply Denied');
    require(msg.value >= price * _amount, 'Ether Amount Denied');
    
    _amount = _amount + _amount / TOKENS_FOR_ONE_FREE;
    for(uint256 i=1; i <= _amount; i++){
      _safeMint(_msgSender(), supply + i);
    }
  }

  // Send balance of contract to address referenced in `vault`
  function withdraw() external payable nonReentrant onlyOwner {
    require(vault != address(0), 'Vault Invalid');
    (bool success, ) = _msgSender().call{value: address(this).balance}("");
    require(success, "Failed to send to vault.");
  }

  // Send amount to address referenced in `vault`
  function withdraw(uint256 amount) external payable nonReentrant onlyOwner {
    require(vault != address(0), 'Vault Invalid');
    (bool success, ) = _msgSender().call{value: amount}("");
    require(success, "Failed to send to vault.");
  }

}