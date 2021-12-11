// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract SweetDreamz is ERC721, Ownable {
  // mint price
  uint256 public ethPrice = 0.04 ether;

  // sale control
  bool public isBurningEnabled;
  bool public isPublicMintingEnabled;
  uint256 public startSaleTimestamp;

  // supply
  uint256 public totalSupply;
  uint256 public maxSupply;
  uint256 public maxPerTxn;
  uint256 public maxPerWallet;

  // wallet for withdrawal
  address payable public payableWallet;

  // metadata uri
  string internal baseTokenUri;
  string internal baseTokenUriExt;

  // track mints of wallet
  mapping(address => uint256) public walletMints;

  // deployment init
  constructor() payable ERC721('Sweet Dreamz', 'SWEETDREAMZ') {
    totalSupply = 0; // Start at Token ID 1
    maxSupply = 7777;
    maxPerTxn = 7;
    maxPerWallet = 7;
    startSaleTimestamp = 1637978400; // @todo set minting date

    // @todo add link location
    baseTokenUri = '';
    baseTokenUriExt = '';

    // @todo Add owner  wallet address here
    payableWallet = payable(
      address(0x23fCF2550686508D2929a8cdD7fc09f3bb95892C)
    );
  }

  /**
   =========================================
   Internal Functions
   @dev these functions are all internal
   =========================================
  */
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }

  /**
   =========================================
   Mint Functions
   @dev these functions are relevant  
      for minting purposes only
   =========================================
  */
  function mintTokens(uint256 quantity) private {
    walletMints[msg.sender] += quantity;
    for (uint256 i = 0; i < quantity; i++) {
      uint256 newTokenId = totalSupply + 1;
      _safeMint(msg.sender, newTokenId);
      totalSupply++;
    }
  }

  function mintPublic(uint256 quantity) public payable {
    require(
      block.timestamp >= startSaleTimestamp,
      'official sale has not started'
    );
    require(isPublicMintingEnabled, 'minting not enabled');
    require(msg.sender == tx.origin, 'Contracts not allowed');
    require(
      isContract(msg.sender) == false,
      'Cannot mint from another contract'
    );
    require(msg.value == getPrice(quantity), 'wrong value');
    require(totalSupply < maxSupply, 'sold out');
    require(totalSupply + quantity <= maxSupply, 'exceeds max supply');
    require(quantity <= maxPerTxn, 'exceeds max per txn');
    require(
      walletMints[msg.sender] + quantity <= maxPerWallet,
      'exceeds max per wallet'
    );

    mintTokens(quantity);
  }

  function reserveTokens(uint256 tokensToReserve) public onlyOwner {
    mintTokens(tokensToReserve);
  }

  /**
   =========================================
   Owner Functions
   @dev these functions can only be called 
      by the owner of contract
   =========================================
  */
  function setPriceInWei(uint256 _price) external onlyOwner {
    ethPrice = _price;
  }

  function setMaxSupply(uint256 _maxSupply) external onlyOwner {
    maxSupply = _maxSupply;
  }

  function setMaxPerWallet(uint256 _maxPerWallet) external onlyOwner {
    maxPerWallet = _maxPerWallet;
  }

  function setMaxPerTxn(uint256 _maxPerTxn) external onlyOwner {
    maxPerTxn = _maxPerTxn;
  }

  function toggleIsBurningEnabled() external onlyOwner {
    isBurningEnabled = !isBurningEnabled;
  }

  function toggleIsPublicMintingEnabled() external onlyOwner {
    isPublicMintingEnabled = !isPublicMintingEnabled;
  }

  function setStartSaleTimestamp(uint256 _startSaleTimestamp)
    external
    onlyOwner
  {
    startSaleTimestamp = _startSaleTimestamp;
  }

  function setBaseTokenUri(string memory newBaseTokenUri) external onlyOwner {
    baseTokenUri = newBaseTokenUri;
  }

  function setBaseTokenUriExt(string memory newBaseTokenUriExt)
    external
    onlyOwner
  {
    baseTokenUriExt = newBaseTokenUriExt;
  }

  function setPayableWallet(address _payableWallet) external onlyOwner {
    payableWallet = payable(_payableWallet);
  }

  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    payable(payableWallet).transfer(balance);
  }

  /**
   ============================================
   Public Functions
   @dev functions that can be called by anyone
   ============================================
  */
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

  function getWalletMintCount(address addr) public view returns (uint256) {
    return walletMints[addr];
  }

  function getPrice(uint256 quantity) public view returns (uint256) {
    return ethPrice * quantity;
  }

  function burn(uint256 tokenId) public {
    require(isBurningEnabled, 'burning is not enabled');
    require(
      _isApprovedOrOwner(_msgSender(), tokenId),
      'caller is not owner nor approved'
    );
    _burn(tokenId);
  }

  function remainingSupply() public view returns (uint256) {
    return maxSupply - totalSupply;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(_exists(tokenId), 'Token does not exist!');
    return
      string(
        abi.encodePacked(
          baseTokenUri,
          Strings.toString(tokenId),
          baseTokenUriExt
        )
      );
  }
}