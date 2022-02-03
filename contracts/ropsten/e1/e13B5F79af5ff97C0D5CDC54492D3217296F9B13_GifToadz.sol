// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AutoIncrementIds.sol";
import "./WhiteList.sol";
import "./CryptoadzChecker.sol";

contract GifToadz is ERC721, Ownable, WhiteList, CryptoadzChecker {
  using Strings for uint256;
  using AutoIncrementIds for AutoIncrementIds.AutoIncrementId;

  AutoIncrementIds.AutoIncrementId private autoIncrementId;

  string public baseURI = ""; // TODO: set to centralise metadata location to start with
  string public URISuffix = ".json";
  bool private isPaused; // default to false
  uint256 private price = 0.069 ether; // cryptoadz original mint price
  uint256 private discountPrice; // 0 by default (reduced gas) - free for first batch
  uint256 private whiteListPrice = 0.02 ether;
  uint256 private preOrderPrice = 0.69 ether; // 10x regular mint price
  uint256 private customOrderPrice = 2 ether; // price for buying specific tokens
  uint256 private maxSupply = 10; // Just 10 for first batch
  uint256 private maxQuantityPerTx = 1; // 1 per transaction for first batch

  constructor() ERC721("GIFToadz", "GIFTOADZ") {}

  /* GETTERS */

  // 25586 gas (FREE)
  // OPTIMISED
  // endpoint expected by open sea
  function totalSupply() external view returns (uint256) {
    return autoIncrementId.current();
  }

  // contains all the info required for web3 UI
  function getContractDetails()
    external
    view
    returns (
      string memory,
      string memory,
      bool,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      name(),
      symbol(),
      isPaused,
      autoIncrementId.current(),
      maxSupply,
      maxQuantityPerTx,
      price,
      discountPrice,
      whiteListPrice,
      preOrderPrice,
      customOrderPrice
    );
  }

  /* MODIFIERS */

  modifier onlyVIP() {
    require(getIsVIP(), "GIFToadz: VIP only");
    _;
  }

  // 23612 gas (FREE) for first condition evaluation
  // OPTIMISED
  // need public getter for web UI
  function getIsVIP() public view returns (bool) {
    return _isWhiteListed(msg.sender) || isToadHolder(msg.sender);
  }

  modifier notPaused() {
    require(!isPaused, "TOADZ: PAUSED");
    _;
  }

  modifier notZeroAddress(address _address) {
    require(_address != address(0), "TOADZ: ZERO ADDRESS");
    _;
  }

  modifier supplyCompliance(uint256 _maxSupply) {
    require(
      _maxSupply > 0 && _maxSupply >= autoIncrementId.current(),
      "TOADZ: Max supply is too small."
    );
    _;
  }

  modifier maxQuantityCompliance(uint256 _maxQuantityPerTx) {
    require(_maxQuantityPerTx > 0, "TOADZ: Max quantity per TX too small.");
    _;
  }

  modifier mintValueCompliance(uint256 _quantity, uint256 _itemPrice) {
    _mintValueCompliance(_quantity, _itemPrice);
    _;
  }

  // OPTIMISED
  function _mintValueCompliance(uint256 _quantity, uint256 _itemPrice)
    internal
    view
  {
    require(msg.value >= _itemPrice * _quantity, "TOADZ: Insufficient funds!");
  }

  modifier mintTxQuantityCompliance(uint256 _quantity) {
    _mintTxQuantityCompliance(_quantity);
    _;
  }

  // OPTIMISED
  function _mintTxQuantityCompliance(uint256 _quantity) internal view {
    require(
      _quantity > 0 && _quantity <= maxQuantityPerTx,
      "TOADZ: Invalid mint quantity!"
    );
  }

  modifier mintSupplyCompliance(uint256 _quantity) {
    _mintSupplyCompliance(_quantity);
    _;
  }

  // OPTIMISED
  function _mintSupplyCompliance(uint256 _quantity) internal view {
    require(
      autoIncrementId.current() + _quantity <= maxSupply,
      "TOADZ: Max supply exceeded!"
    );
  }

  modifier mintCompliance(uint256 _quantity, uint256 _itemPrice) {
    _mintTxQuantityCompliance(_quantity);
    _mintSupplyCompliance(_quantity);
    _mintValueCompliance(_quantity, _itemPrice);
    _;
  }

  /* BASIC SETTERS */

  // 30819 gas
  // OPTIMISED
  function setMaxSupply(uint256 _maxSupply)
    external
    onlyOwner
    supplyCompliance(_maxSupply)
  {
    maxSupply = _maxSupply;
  }

  // 28686 gas
  // OPTIMISED
  function setMaxQuantityPerTx(uint256 _maxQuantityPerTx)
    external
    onlyOwner
    maxQuantityCompliance(_maxQuantityPerTx)
  {
    maxQuantityPerTx = _maxQuantityPerTx;
  }

  // 28736 gas
  // OPTIMISED
  function setPrice(uint256 _price) external onlyOwner {
    price = _price;
  }

  // 28715 gas
  // OPTIMISED
  function setWhiteListPrice(uint256 _whiteListPrice) external onlyOwner {
    whiteListPrice = _whiteListPrice;
  }

  // 28704 - 45816 depending on if it had a storage slot used at initialisation
  // OPTIMISED
  function setDiscountPrice(uint256 _discountPrice) external onlyOwner {
    discountPrice = _discountPrice;
  }

  // 25826 gas
  // OPTIMISED
  function setPreOrderPrice(uint256 _preOrderPrice) external onlyOwner {
    preOrderPrice = _preOrderPrice;
  }

  // 28832 gas
  // OPTIMISED
  function setCustomOrderPrice(uint256 _customOrderPrice) external onlyOwner {
    customOrderPrice = _customOrderPrice;
  }

  // 28655 gas
  // OPTIMISED
  // a fail safe owner function to update the autoIncrementId value if it gets stuck
  function setCurrentId(uint256 _id) external onlyOwner {
    autoIncrementId.setCurrentId(_id);
  }

  /* WHITE LISTING */

  // 45952 gas
  // FULLY OPTIMISED
  function enterWhiteList() external payable {
    require(msg.value >= whiteListPrice, "TOADZ: Insufficient funds!");
    _enterWhiteList();
  }

  // 46453 gas
  // FULLY OPTIMISED
  function addAddressToWhiteList(address _address) external onlyOwner {
    _addToWhiteList(_address);
  }

  // 24611 gas
  // FULLY OPTIMISED
  function removeAddressFromWhiteList(address _address) external onlyOwner {
    _removeFromWhiteList(_address);
  }

  // 26245 gas (FREE)
  // FULLY OPTIMISED
  function getIsWhiteListed(address _address)
    external
    view
    onlyOwner
    returns (bool)
  {
    return _isWhiteListed(_address);
  }

  /* MINTING */

  // gas pricing for sequential standard mint with no interrupts
  // 1: 65816 $10
  // 5: 168460
  // 10: 296765
  function mint(uint256 _quantity) external payable {
    _standardMint(_quantity, price);
  }

  function whiteListMint(uint256 _quantity) external payable onlyVIP {
    _standardMint(_quantity, discountPrice);
  }

  function _standardMint(uint256 _quantity, uint256 _price)
    internal
    notPaused
    mintCompliance(_quantity, _price)
  {
    _mintLoop(msg.sender, _quantity);
  }

  function customMint(uint256 _tokenId)
    external
    payable
    notPaused
    mintValueCompliance(1, customOrderPrice)
  {
    _safeMint(msg.sender, _tokenId);
  }

  // Allow pre-order mints to exceed the maxSupply value.
  // This doubles as a pre-batch release sale feature and a post-mint custom order feature
  function preOrderMint(uint256 _quantity)
    external
    payable
    notPaused
    mintTxQuantityCompliance(_quantity)
    mintValueCompliance(_quantity, preOrderPrice)
  {
    _mintLoop(msg.sender, _quantity);
  }

  // unrestricted owner function to exceed supply and send tokens to any address
  function mintForAddress(address _receiver, uint256 _quantity)
    external
    onlyOwner
  {
    _mintLoop(_receiver, _quantity);
  }

  // 54063 gas
  // OPTIMISED
  // unrestricted owner function allowing specific token minting for any address
  function mintTokenForAddress(address _receiver, uint256 _tokenId)
    external
    onlyOwner
  {
    _safeMint(_receiver, _tokenId);
  }

  // The core mint function.
  // It is the only function that directly writes to the ERC721 to create and update tokens
  // This loop will allow only one final transaction to exceed the max supply if it encounters preorder ids after the current id.
  // We can manually create X number of additional tokens for the wallet that encounters the final transaction and over-mints.
  function _mintLoop(address _receiver, uint256 _quantity) internal {
    uint256 currentId = autoIncrementId.current();
    // increment before mint (autoIncrementId starts at 0)
    unchecked {
      currentId += 1;
    }

    for (uint256 i = 0; i < _quantity; i++) {
      // keep increasing memory id until an available id is found
      while (_exists(currentId)) {
        unchecked {
          currentId += 1;
        }
      }
      _safeMint(_receiver, currentId);
    }

    // write to autoIncrementId once per batch to keep gas lower
    autoIncrementId.setCurrentId(currentId);
  }

  /* CONTROLS */

  // 79230 gas
  // OPTIMISED
  function releaseBatch(
    uint256 _price,
    uint256 _discountPrice,
    uint256 _whiteListPrice,
    uint256 _preOrderPrice,
    uint256 _customOrderPrice,
    uint256 _maxSupply,
    uint256 _maxQuantityPerTx
  )
    external
    onlyOwner
    supplyCompliance(_maxSupply)
    maxQuantityCompliance(_maxQuantityPerTx)
  {
    price = _price;
    discountPrice = _discountPrice;
    whiteListPrice = _whiteListPrice;
    preOrderPrice = _preOrderPrice;
    customOrderPrice = _customOrderPrice;
    maxSupply = _maxSupply;
    maxQuantityPerTx = _maxQuantityPerTx;
  }

  // 45907 gas for first use - 23469 gas update
  // OPTIMISED
  function setIsPaused(bool _isPaused) external onlyOwner {
    isPaused = _isPaused;
  }

  /* FINANCE */

  // 21315 gas
  /**
   * @dev If a function is payable, then the money value is received into the smart contract address automatically.
   * @notice Any amount can be deposited into the contract.
   */
  function deposit() external payable {}

  // 23444 gas (FREE)
  // OPTIMISED
  function getBalance() external view onlyOwner returns (uint256) {
    return address(this).balance;
  }

  // 30963 gas
  // OPTIMISED
  /**
   *   @dev Uses call to protect against send/transfer gas limited re-entrancy.
   *   @notice Withdraws specified amount from the contract balance to the owner wallet.
   */
  function withdrawBalance(uint256 _amount) external onlyOwner {
    _transferBalance(payable(owner()), _amount);
  }

  // 31309 gas
  // OPTIMISED
  function transferBalance(address _to, uint256 _amount)
    external
    onlyOwner
    notZeroAddress(_to)
  {
    _transferBalance(payable(_to), _amount);
  }

  // OPTIMISED
  function _transferBalance(address payable _to, uint256 _amount)
    internal
    onlyOwner
  {
    /// @dev gas optimisation: use explicit balance reference instead of getter function
    require(_amount <= address(this).balance, "TOADZ: INSUFFICIENT BALANCE");
    (bool success, ) = _to.call{value: _amount}("");
    require(success);
  }

  /// @dev Essential fallback functions if a payable function reverts to still accept currency
  receive() external payable {} // if no data field

  fallback() external payable {} // if data was there

  /* METADATA */

  // gas changes based on string length
  // OPTIMISED
  function setBaseURI(string memory _baseURI) external onlyOwner {
    baseURI = _baseURI;
  }

  // gas changes based on string length
  // OPTIMISED
  function setURISuffix(string memory _URISuffix) external onlyOwner {
    URISuffix = _URISuffix;
  }

  // gas depends on string length (FREE)
  // OPTIMISED
  function tokenURI(uint256 _tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(_exists(_tokenId), "TOADZ: No such token!");
    return string(abi.encodePacked(baseURI, _tokenId.toString(), URISuffix));
  }
}