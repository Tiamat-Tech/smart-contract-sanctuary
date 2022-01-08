//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ThirdWorldHumansTest is ERC721, Ownable {
  using Counters for Counters.Counter;
  using ECDSA for bytes32;

  Counters.Counter private _tokenIdCounter;

  /*************
   * CONSTANTS *
   *************/

  uint256 public constant TOTAL_SUPPLY = 4444;
  uint256 public constant RESERVED_SUPPLY = 194;
  uint256 public constant PRESALE_MAX_SUPPLY = 2400;

  // MINTING LIMITS
  uint256 public constant MINT_TX_LIMIT = 3;
  uint256 public constant MAX_PER_WALLET_PRESALE = 2;
  uint256 public constant MAX_PER_WALLET = 6;

  // PRICE
  uint256 public constant PUBLIC_PRICE = 0.0666 ether;
  uint256 public constant PRESALE_PRICE = 0.0444 ether;

  // STATUS
  bool public isPresaleActive = false;
  bool public isPublicSaleActive = false;
  bool private _globalPaused = false;

  /************
   * MAPPINGS *
   ************/

  mapping(string => bool) private _usedNonces;
  mapping(address => uint256) private _totalMintedByAddress; // PULIC + PRESALE
  mapping(address => uint256) private _presaleMintedByAddress; // PRESALE

  /*******************
   * SUPPLY COUNTERS *
   *******************/

  uint256 public currentTotalSupply = 0;
  uint256 public currentPresaleSupply = 0;
  uint256 public currentReservedSupply = 0;

  /****************
   * METADATA URI *
   ****************/

  string private _baseTokenURI = "ipfs://";
  string private _contractURI;

  /****************
   * TEAM WALLETS *
   ****************/

  address private _signerAddress; // Backend Signer Account
  address private _paymentAddress; // Multisig Account - For Withdrawals

  /*************
   * MODIFIERS *
   *************/

  modifier onlyWhenPresaleActive() {
    require(isPresaleActive, "PRESALE_NOT_ACTIVE");
    _;
  }

  modifier onlyWhenPublicSaleActive() {
    require(isPublicSaleActive, "PUBLIC_SALE_NOT_ACTIVE");
    _;
  }

  modifier onlyWhenNotPaused() {
    require(!_globalPaused, "CONTRACT_PAUSED");
    _;
  }

  /***************
   * CONSTRUCTOR *
   ***************/
   
  constructor() ERC721("Some Secret Project V1", "VSP") {
    // So that first minter doesn't pay extra GAS, Say thanks on discord:)
    _tokenIdCounter.increment();
  }

  /***************************
   * CONTRACT STATUS HELPERS *
   ***************************/

  function setPresaleStatus(bool newStatus) external onlyOwner {
    isPresaleActive = newStatus;
  }

  function setPublicSaleStatus(bool newStatus) external onlyOwner {
    isPublicSaleActive = newStatus;
  }

  function setGlobalPaused(bool newStatus) external onlyOwner {
    _globalPaused = newStatus;
  }

  function getGlobalPaused() public view returns (bool) {
    return _globalPaused;
  }

  /****************************
   * INTERNAL ADDRESS HELPERS *
   ****************************/

  // Getters
  function getSignerAddress() public view returns (address) {
    return _signerAddress;
  }

  function getPaymentAddress() public view returns (address) {
    return _paymentAddress;
  }

  // Setters
  function setSignerAddress(address _newSignerAddress) public onlyOwner {
    require(_newSignerAddress != address(0), "ZERO_ADDRESS");
    require(_newSignerAddress != _signerAddress, "MATCHES_OLD_SIGNER");

    _signerAddress = _newSignerAddress;
  }

  function setPaymentAddress(address _newPaymentAddress) external onlyOwner {
    require(_newPaymentAddress != address(0), "ZERO_ADDRESS");
    require(_newPaymentAddress != _paymentAddress, "MATCHES_OLD_PAYEE");

    _paymentAddress = _newPaymentAddress;
  }

  /*********************
   * USER MINT HELPERS *
   *********************/

  function mintPublic(uint256 quantity)
    external
    payable
    onlyWhenPublicSaleActive
    onlyWhenNotPaused
  {
    require(tx.origin == msg.sender, "BOT_REJECTION");

    require(quantity > 0, "QUANTITY_CANNOT_BE_ZERO");

    require(quantity <= MINT_TX_LIMIT, "MINT_LIMIT_EXCEEDED");

    require(PUBLIC_PRICE * quantity == msg.value, "INVALID_ETH_AMOUNT");

    require(
      _totalMintedByAddress[msg.sender] + quantity <= MAX_PER_WALLET,
      "EXCEEDS_MAX_PER_WALLET"
    );

    require(
      currentTotalSupply + quantity <= TOTAL_SUPPLY,
      "EXCEEDS_TOTAL_SUPPLY"
    );

    for (uint256 i = 0; i < quantity; i++) {
      _mintSingleNFT();
    }
  }

  function mintPresale(
    uint256 quantity,
    bytes32 hash,
    string memory nonce,
    bytes memory signature
  ) external payable onlyWhenPresaleActive onlyWhenNotPaused {
    require(tx.origin == msg.sender, "BOT_REJECTION");

    require(quantity > 0, "QUANTITY_CANNOT_BE_ZERO");

    require(
      _presaleMintedByAddress[msg.sender] + quantity <= MAX_PER_WALLET_PRESALE,
      "EXCEEDS_MAX_PER_WALLET_PRESALE"
    );

    require(PRESALE_PRICE * quantity == msg.value, "INVALID_ETH_AMOUNT");

    require(
      _totalMintedByAddress[msg.sender] + quantity <= MAX_PER_WALLET,
      "EXCEEDS_MAX_PER_WALLET"
    );

    require(
      currentPresaleSupply + quantity <= PRESALE_MAX_SUPPLY,
      "EXCEEDS_PRESALE_MAX_SUPPLY"
    );

    // Check if the address signer is the same as the _signerAddress, preventing direct minting.
    require(_matchAddresSigner(hash, signature), "DIRECT_MINT_DISALLOWED");

    // This is required to prevent someone from re-using the same signature and hash combination to mint again.
    require(!_usedNonces[nonce], "NONCE_USED");

    // Verify if the keccak256 hash matches the hash generated by the _hashTransaction function
    require(_hashTransaction(msg.sender, quantity, nonce) == hash, "HASH_FAIL");

    for (uint256 i = 0; i < quantity; i++) {
      _mintSingleNFT();
    }

    // Add the nonce to the list of already used nonce
    _usedNonces[nonce] = true;
    currentPresaleSupply += quantity;
  }

  /*************
   * TEAM MINT *
   *************/

  function teamMint(uint256 quantity) external onlyOwner onlyWhenNotPaused {
    require(
      currentReservedSupply + quantity <= RESERVED_SUPPLY,
      "EXCEEDS_RESERVED_SUPPLY"
    );
    require(
      currentTotalSupply + quantity <= TOTAL_SUPPLY,
      "EXCEEDS_TOTAL_SUPPLY"
    );

    for (uint256 i = 0; i < quantity; i++) {
      _mintSingleNFT();
    }

    currentReservedSupply += quantity;
  }

  /*******************
   * MINT SINGLE NFT *
   *******************/

  function _mintSingleNFT() private {
    _safeMint(msg.sender, _tokenIdCounter.current());
    _tokenIdCounter.increment();
    currentTotalSupply += 1;
    _totalMintedByAddress[msg.sender] += 1;
  }

  /*******************
   * SIGNATURE HELPERS *
   ********************/

  function _hashTransaction(
    address sender,
    uint256 qty,
    string memory nonce
  ) private pure returns (bytes32) {
    bytes32 hash = keccak256(abi.encodePacked(sender, qty, nonce));
    return hash.toEthSignedMessageHash();
  }

  /// Check if the current _signerAddress is the same as the one given in the hash by the server-side API
  /// @param hash contains the ABI encoded user address, the quantity of NFT to mint and nonce
  /// @param signature signature generated by the backend from a private key
  function _matchAddresSigner(bytes32 hash, bytes memory signature)
    private
    view
    returns (bool)
  {
    return _signerAddress == hash.recover(signature);
  }

  /********************
   * METADATA HELPERS *
   ********************/

  /// Set the base URI for the tokens metadata
  function setBaseURI(string calldata newBaseUri) external onlyOwner {
    _baseTokenURI = newBaseUri;
  }

  function getBaseURI() public view returns (string memory) {
    return _baseTokenURI;
  }

  /// Smart-contract metadata
  /// @dev see https://docs.opensea.io/docs/contract-level-metadata
  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  // Get current Base URI
  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  /// Set smart-contract metadata URI
  function setContractURI(string calldata newContractURI) external onlyOwner {
    _contractURI = newContractURI;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  /*****************
   * ETH WITHDRAWAL*
   *****************/

  function withdrawAll() external onlyOwner {
    require(
      address(_paymentAddress) != address(0),
      "Payment Address cannot be ZERO"
    );
    (bool success, ) = payable(_paymentAddress).call{
      value: address(this).balance
    }("");
    require(success, "Withdrawal Failed.");
  }

  /************************
   * TOKEN TRANSFER HOOK  *
   ************************/

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override onlyWhenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId);
  }
}