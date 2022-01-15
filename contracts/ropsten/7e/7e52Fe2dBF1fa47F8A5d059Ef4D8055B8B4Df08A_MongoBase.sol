// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract MongoBase is ERC721Upgradeable {
  using StringsUpgradeable for uint256;
  using ECDSAUpgradeable for bytes32;

  /** Variable Declarations */
  uint256 public MAX;
  uint256 public PRESALE_PRICE;
  uint256 public SALE_PRICE;
  uint256 public MAX_PER_TXN;
  uint256 private _TIMEOUT;
  uint256 private _tokensMinted;

  string private _contractURI;
  string private _tokenBaseURI;
  string public statsproof;
  string public scriptproof;

  address public _signerAddress;
  address private _owner;
  bool public presaleLive;
  bool public saleLive;
  bool public isBase;
  bool public init;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  modifier onlyOwner() {
    require(_owner == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {
    isBase = true;
    init = true;
    _owner = msg.sender;
  }

  function initialize(
    string calldata tokenName,
    string calldata symbol,
    address contractowner,
    address signerAddress,
    uint256 max,
    uint256 presalePrice,
    uint256 salePrice,
    uint256 maxPerTxn
  ) public initializer {
    require(isBase == false, "ERROR: This is the Base");
    require(init == false, "ERROR: already initialized");
    require(_owner == address(0), "ERROR: Contract already initialized");

    init = true;

    __ERC721_init(tokenName, symbol);

    _owner = contractowner;
    _TIMEOUT = 45;

    _signerAddress = signerAddress;
    MAX = max;
    PRESALE_PRICE = presalePrice;
    SALE_PRICE = salePrice;
    MAX_PER_TXN = maxPerTxn;
  }

  //**** Mint/Purchase functions ****//

  /**
   * @dev checks hash and signature
   */
  function matchAddressSigner(bytes32 hash, bytes memory signature) private view returns (bool) {
    return _signerAddress == hash.recover(signature);
  }

  /**
   * @dev generates hash
   */
  function hashTransaction(
    address sender,
    uint256 tokenQuantity,
    uint256 timeStamp
  ) private pure returns (bytes32) {
    bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(sender, tokenQuantity, timeStamp))));

    return hash;
  }

  /**
   * @dev Public Sales Buy/Mint function
   */
  function Buy(
    uint256 tokenQuantity,
    uint256 timeStamp,
    bytes memory signature
  ) external payable {
    address wallet = msg.sender;
    uint256 tokenQty = tokenQuantity;
    uint256 totalMinted = _tokensMinted;

    require(saleLive, "SALE_NOT_STARTED");
    if (MAX > 0) require(totalMinted + tokenQty <= MAX, "OUT_OF_STOCK");
    if (MAX_PER_TXN > 0) require(tokenQty <= MAX_PER_TXN, "EXCEED_MAX_PER_TXN");
    require(SALE_PRICE * tokenQty <= msg.value, "INSUFFICIENT_ETH");
   if (_signerAddress != address(0)) require(matchAddressSigner(hashTransaction(wallet, tokenQty, timeStamp), signature), "SIGNATURE_ERR");
    require(block.timestamp <= timeStamp + _TIMEOUT, "TIMED_OUT");

    _tokensMinted += tokenQty;

    for (uint256 i = 0; i < tokenQty; i++) {
      totalMinted++;
      _mint(wallet, totalMinted);
    }
    delete wallet;
    delete tokenQty;
    delete totalMinted;
  }

  /**
   * @dev Pre-Sale Buy/Mint function
   */
  function presaleBuy(
    uint256 tokenQuantity,
    uint256 timeStamp,
    bytes memory signature
  ) external payable {
    address wallet = msg.sender;
    uint256 tokenQty = tokenQuantity;
    uint256 totalMinted = _tokensMinted;

    require(presaleLive, "PRE_SALE_NOT_ACTIVE");
    require(totalMinted + tokenQty <= MAX, "OUT_OF_STOCK");
    require(tokenQty <= MAX_PER_TXN, "EXCEED_MAX_PER_TXN");
    require(PRESALE_PRICE * tokenQty <= msg.value, "INSUFFICIENT_ETH");
    require(matchAddressSigner(hashTransaction(wallet, tokenQty, timeStamp), signature), "SIGNATURE_ERR");
    require(block.timestamp <= timeStamp + _TIMEOUT, "TIMED_OUT");

    _tokensMinted += tokenQty;

    for (uint256 i = 0; i < tokenQty; i++) {
      totalMinted++;
      _mint(wallet, totalMinted);
    }
    delete wallet;
    delete tokenQty;
    delete totalMinted;
  }

  /**
   * @dev gift Claim
   */

  function giftClaim(
    uint256 tokenQuantity,
    uint256 timeStamp,
    bytes memory signature
  ) external {
    address wallet = msg.sender;
    uint256 tokenQty = tokenQuantity;
    uint256 totalMinted = _tokensMinted;

    require(totalMinted + tokenQty <= MAX, "OUT_OF_STOCK");
    require(matchAddressSigner(hashTransaction(wallet, tokenQty, timeStamp), signature), "SIGNATURE_ERR");
    require(block.timestamp <= timeStamp + _TIMEOUT, "TIMED_OUT");

    _tokensMinted += tokenQty;

    for (uint256 i = 0; i < tokenQty; i++) {
      totalMinted++;
      _mint(wallet, totalMinted);
    }
    delete wallet;
    delete tokenQty;
    delete totalMinted;
  }

  /**
   * @dev giveaways
   */
  function giveaway(address[] calldata receivers) external onlyOwner {
    uint256 totalMinted = _tokensMinted;
    uint256 giftAddresses = receivers.length;

    require(totalMinted + giftAddresses <= MAX, "OUT_OF_STOCK");

    _tokensMinted += giftAddresses;

    for (uint256 i = 0; i < giftAddresses; i++) {
      totalMinted++;
      _mint(receivers[i], totalMinted);
    }
    delete giftAddresses;
    delete totalMinted;
  }

  //**** Owner functions ****//

  /**
   * @dev withdraw
   */
  function withdraw() external onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  /**
   * @dev toggle Presale
   */
  function togglePresale() external onlyOwner {
    presaleLive = !presaleLive;
  }

  /**
   * @dev toggle sale
   */
  function toggleSale() external onlyOwner {
    saleLive = !saleLive;
  }

  /**
   * @dev change Signer Add for gift Claims
   */
  function setSignerAddress(address signerAddress) external onlyOwner {
    _signerAddress = signerAddress;
  }

  /**
   * @dev set Provenance hash
   */
  function setProvenanceHash(string calldata hash) external onlyOwner {
    statsproof = hash;
  }

  /**
   * @dev set Meta Generator Script hash
   */
  function setScriptHash(string calldata hash) external onlyOwner {
    scriptproof = hash;
  }

  /**
   * @dev set Contract URI
   */
  function setContractURI(string calldata URI) external onlyOwner {
    _contractURI = URI;
  }

  /**
   * @dev set Base URI
   */
  function setBaseURI(string calldata URI) external onlyOwner {
    _tokenBaseURI = URI;
  }

  //**** View functions ****//
  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
    require(_exists(tokenId), "Cannot query non-existent token");
    string memory json = ".json";
    return string(abi.encodePacked(_tokenBaseURI, tokenId.toString(), json));
  }

  function baseURI() public view returns (string memory) {
    return _tokenBaseURI;
  }

  /**
   * @dev totalSupply()
   */
  function totalSupply() public view virtual returns (uint256) {
    return _tokensMinted;
  }

  /**
   * @dev Returns the address of the current owner.
   */
  function owner() public view virtual returns (address) {
    return _owner;
  }

  /**
   * @dev Leaves the contract without owner. It will not be possible to call
   * `onlyOwner` functions anymore. Can only be called by the current owner.
   *
   * NOTE: Renouncing ownership will leave the contract without an owner,
   * thereby removing any functionality that is only available to the owner.
   */
  function renounceOwnership() public virtual onlyOwner {
    _transferOwnership(address(0));
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Can only be called by the current owner.
   */
  function transferOwnership(address newOwner) public virtual onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    _transferOwnership(newOwner);
  }

  /**
   * @dev Transfers ownership of the contract to a new account (`newOwner`).
   * Internal function without access restriction.
   */
  function _transferOwnership(address newOwner) internal virtual {
    address oldOwner = _owner;
    _owner = newOwner;
    emit OwnershipTransferred(oldOwner, newOwner);
  }
}