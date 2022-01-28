// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721A.sol";
import "./utils/Counters.sol";
import "./access/Ownable.sol";
import "./security/ReentrancyGuard.sol";
import "./utils/cryptography/MerkleProof.sol";

contract QO is Ownable, ERC721A, ReentrancyGuard {
  string private name_ = "[QO]Test";
  string private symbol_ = "[QO]";
  uint256 public immutable maxTokensPerTx;
  uint256 public immutable maxTokensInPresale;
  uint256 public immutable maxTokensForDevs;
  bytes32 public immutable revealURIHash;
  bool public frozen;

  struct SaleConfig {
    uint32 preSaleStartTime;
    uint32 publicSaleStartTime;
    uint64 price;
  }

  SaleConfig public saleConfig;

  bytes32 public merkleRoot;

  string private _baseTokenURI;

  mapping(address => uint256) private _tokensClaimedInPresale;

  constructor(
    uint256 maxBatchSize_,
    uint256 collectionSize_,
    uint256 maxTokensInPreSale_,
    uint256 maxTokensForDevs_,
    bytes32 revealURIHash_,
    uint32 preSaleStartTime_,
    uint32 publicSaleStartTime_,
    uint64 price_,
    bytes32 merkleRoot_,
    string memory baseURI_
  ) ERC721A(name_, symbol_, maxBatchSize_, collectionSize_) {
    maxTokensPerTx = maxBatchSize_;
    maxTokensInPresale = maxTokensInPreSale_;
    maxTokensForDevs = maxTokensForDevs_;
    revealURIHash = revealURIHash_;
    saleConfig.preSaleStartTime = preSaleStartTime_;
    saleConfig.publicSaleStartTime = publicSaleStartTime_;
    saleConfig.price = price_;
    merkleRoot = merkleRoot_;
    _baseTokenURI = baseURI_;
  }

  function preSaleMint(uint256 quantity, bytes32[] memory proof) external payable {
    uint256 price = uint256(saleConfig.price);
    require(price != 0, "Presale has not started yet");
    uint256 preSaleStartTime = uint256(saleConfig.preSaleStartTime);
    require(preSaleStartTime != 0 && block.timestamp >= preSaleStartTime,
      "Presale has not started yet");
    if (MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender)))) {
      require(_tokensClaimedInPresale[msg.sender] + quantity <= maxTokensInPresale,
        "Exceeded presale limit");
      require(price * quantity <= msg.value, "Ether value sent is not correct");
      _safeMint(msg.sender, quantity);
    } else {
      revert("Address is not on the presale list");
    }
    _tokensClaimedInPresale[msg.sender] += quantity;
  }

  function publicSaleMint(uint256 quantity) external payable {
    SaleConfig memory config = saleConfig;
    uint256 price = uint256(config.price);
    require(price != 0, "Public sale has not started yet");
    uint256 publicSaleStartTime = uint256(config.publicSaleStartTime);
    require(publicSaleStartTime != 0 && block.timestamp >= publicSaleStartTime,
      "Public sale has not started yet");
    require(totalSupply() + quantity <= collectionSize, "Exceeded max supply");
    require(price * quantity <= msg.value, "Ether value sent is not correct");
    _safeMint(msg.sender, quantity);
  }

  function devMint(address _to, uint256 quantity) external onlyOwner {
    require(totalSupply() + quantity <= maxTokensForDevs, "Exceeded dev limit");
    require(quantity <= maxBatchSize, "Exceeded maxBatchSize");
    _safeMint(_to, quantity);
  }

  function setPublicSaleStartTime(uint32 timestamp) external onlyOwner {
    saleConfig.publicSaleStartTime = timestamp;
  }

  function setPreSaleStartTime(uint32 timestamp) external onlyOwner {
    saleConfig.preSaleStartTime = timestamp;
  }

  function setPrice(uint64 price) external onlyOwner {
    saleConfig.price = price;
  }

  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    require(!frozen, "URI cannot be changed");
    _baseTokenURI = baseURI;
  }
  
  function reveal(string calldata baseURI) external onlyOwner {
    require(keccak256(abi.encodePacked(baseURI)) == revealURIHash, "URI does not match");
    _baseTokenURI = baseURI;
  }

  function freeze() external onlyOwner {
    frozen = true;
  }

  function withdraw() external onlyOwner nonReentrant {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
    _setOwnersExplicit(quantity);
  }

  function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
  }

  function getOwnershipData(uint256 tokenId)
    external
    view
    returns (TokenOwnership memory)
  {
    return ownershipOf(tokenId);
  }
}