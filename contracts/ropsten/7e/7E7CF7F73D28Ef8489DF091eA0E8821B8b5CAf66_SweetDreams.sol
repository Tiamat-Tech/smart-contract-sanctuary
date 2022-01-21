// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract SweetDreams is ERC721, Ownable {
  // sale control
  uint256 public mintPrice = 0.05 ether;
  uint256 public publicSaleTime;
  bool public isPublicMintEnabled;

  // whitelist
  bool public isWhitelistMintEnabled;
  bytes32 private merkleRoot;

  // supply
  uint256 public totalSupply;
  uint256 public maxSupply;
  uint256 public maxPerTxn;
  uint256 public maxPerWalletWhitelist;

  // metadata uri
  string internal baseTokenUri;
  string internal baseTokenUriExt;

  // wallet trackable
  address payable public ownerWallet;
  mapping(address => uint256) public walletWhitelistMints;

  constructor() payable ERC721('Sweet Dreams', 'SWEETDREAMS') {
    totalSupply = 0;
    maxSupply = 4242;
    maxPerTxn = 10;
    maxPerWalletWhitelist = 5;
    publicSaleTime = 1637978400; // @todo set minting date
    ownerWallet = payable(address(0x23fCF2550686508D2929a8cdD7fc09f3bb95892C)); // @todo Add owner wallet address here
  }

  /**
   =========================================
   Owner Functions
   @dev these functions can only be called 
      by the owner of contract
   =========================================
  */
  function setIsPublicMintEnabled(bool isPublicMintEnabled_)
    external
    onlyOwner
  {
    isPublicMintEnabled = isPublicMintEnabled_;
  }

  function setIsWhitelistMintEnabled(bool isWhitelistMintEnabled_)
    external
    onlyOwner
  {
    isWhitelistMintEnabled = isWhitelistMintEnabled_;
  }

  function setMerkleRoot(bytes32 merkleRoot_) external onlyOwner {
    merkleRoot = merkleRoot_;
  }

  function setPublicSaleTime(uint256 setPublicSaleTime_) external onlyOwner {
    publicSaleTime = setPublicSaleTime_;
  }

  function setBaseTokenUri(string memory newBaseTokenUri_) external onlyOwner {
    baseTokenUri = newBaseTokenUri_;
  }

  function setBaseTokenUriExt(string memory newBaseTokenUriExt_)
    external
    onlyOwner
  {
    baseTokenUriExt = newBaseTokenUriExt_;
  }

  function setPriceInWei(uint256 price_) external onlyOwner {
    mintPrice = price_;
  }

  function setMaxSupply(uint256 maxSupply_) external onlyOwner {
    maxSupply = maxSupply_;
  }

  function setMaxPerWalletWhitelist(uint256 maxPerWalletWhitelist_)
    external
    onlyOwner
  {
    maxPerWalletWhitelist = maxPerWalletWhitelist_;
  }

  function setMaxPerTxn(uint256 maxPerTxn_) external onlyOwner {
    maxPerTxn = maxPerTxn_;
  }

  function setOwnerWallet(address ownerWallet_) external onlyOwner {
    ownerWallet = payable(ownerWallet_);
  }

  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    payable(ownerWallet).transfer(balance);
  }

  /**
   =========================================
   Mint Functions
   @dev these functions are relevant  
      for minting purposes only
   =========================================
  */
  function mintTokens(uint256 quantity_) private {
    for (uint256 i = 0; i < quantity_; i++) {
      uint256 newTokenId = totalSupply + 1;
      totalSupply++;
      _safeMint(msg.sender, newTokenId);
    }
  }

  function commonMintingRules(uint256 value_, uint256 quantity_) private view {
    require(value_ == getPrice(quantity_), 'wrong value');
    require(totalSupply < maxSupply, 'sold out');
    require(totalSupply + quantity_ <= maxSupply, 'exceeds max supply');
    require(quantity_ <= maxPerTxn, 'exceeds max per txn');
  }

  function mintPublic(uint256 quantity_) public payable {
    require(block.timestamp >= publicSaleTime, 'not public sale time yet');
    require(isPublicMintEnabled, 'minting not enabled');
    require(tx.origin == msg.sender, 'contracts not allowed');
    commonMintingRules(msg.value, quantity_);
    mintTokens(quantity_);
  }

  function mintWhitelist(
    uint256 quantity_,
    bytes32[] memory proof_,
    bytes32 leaf_
  ) public payable {
    require(isWhitelistMintEnabled, 'minting not enabled');
    require(tx.origin == msg.sender, 'contracts not allowed');
    require(
      MerkleProof.verify(proof_, merkleRoot, leaf_),
      'address supplied is not on the whitelist'
    );
    require(
      walletWhitelistMints[msg.sender] + quantity_ <= maxPerWalletWhitelist,
      'exceeds max wallet'
    );
    commonMintingRules(msg.value, quantity_);
    walletWhitelistMints[msg.sender] += quantity_;
    mintTokens(quantity_);
  }

  function mintOwner(uint256 quantity_) external onlyOwner {
    mintTokens(quantity_);
  }

  /**
   ============================================
   Public & External Functions
   @dev functions that can be called by anyone
   ============================================
  */
  function checkWhitelist(bytes32[] memory proof_, bytes32 leaf_)
    external
    view
    returns (bool)
  {
    return MerkleProof.verify(proof_, merkleRoot, leaf_);
  }

  function multiTransferFrom(
    address from_,
    address to_,
    uint256[] memory tokenIds_
  ) public {
    for (uint256 i = 0; i < tokenIds_.length; i++) {
      transferFrom(from_, to_, tokenIds_[i]);
    }
  }

  function multiSafeTransferFrom(
    address from_,
    address to_,
    uint256[] memory tokenIds_,
    bytes memory data_
  ) public {
    for (uint256 i = 0; i < tokenIds_.length; i++) {
      safeTransferFrom(from_, to_, tokenIds_[i], data_);
    }
  }

  function walletOfOwner(address address_)
    public
    view
    returns (uint256[] memory)
  {
    uint256 _balance = balanceOf(address_);
    uint256[] memory _tokens = new uint256[](_balance);
    uint256 _index;

    for (uint256 i = 0; i < maxSupply; i++) {
      if (address_ == ownerOf(i)) {
        _tokens[_index] = i;
        _index++;
      }
    }

    return _tokens;
  }

  function getPrice(uint256 quantity_) public view returns (uint256) {
    return mintPrice * quantity_;
  }

  function getRemainingSupply() public view returns (uint256) {
    return maxSupply - totalSupply;
  }

  function burn(uint256 tokenId_) public {
    require(
      _isApprovedOrOwner(_msgSender(), tokenId_),
      'caller is not owner nor approved'
    );
    _burn(tokenId_);
  }

  function tokenURI(uint256 tokenId_)
    public
    view
    override
    returns (string memory)
  {
    require(_exists(tokenId_), 'Token does not exist!');
    return
      string(
        abi.encodePacked(
          baseTokenUri,
          Strings.toString(tokenId_),
          baseTokenUriExt
        )
      );
  }
}