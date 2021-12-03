// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CyberAssassins is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
  using Strings for string;
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  uint256 public constant MAX_REGULAR_TOKENS = 10000;
  uint256 public constant MAX_SUPER_TOKENS = 5000;
  uint256 public constant MAX_ULTIMATE_TOKENS = 3333;
  uint256 public constant PRICE = 0.05 ether;
  uint256 private constant REGULAR_START_AT = 0;
  uint256 private constant SUPER_START_AT = 10000;
  uint256 private constant ULTIMATE_START_AT = 15000;

  uint256 public whitelistMaxMint = 3;
  string public baseTokenURI;
  bool private PAUSE = true;
  bool private WHITELISTPAUSE = true;

  /**
   * @dev The tracker of assassins (Regular, Super, Ultimate)
   */
  Counters.Counter private _tokenIdRegularTracker;
  Counters.Counter private _tokenIdSuperTracker;
  Counters.Counter private _tokenIdUltimateTracker;

  /**
   * @dev The count of minted assassins (Regular, Super, Ultimate)
   */
  uint256 private _regularTokenCounter;
  uint256 private _superTokenCounter;
  uint256 private _ultimateTokenCounter;

  /**
   * @dev The whitelist
   */
  mapping(address => bool) private _whitelist;
  mapping(address => uint256) private _whitelistClaimed;

  event PauseEvent(bool pause);
  event welcomeToAssassin(uint256 indexed id);

  constructor() ERC721("Cyber Assassins", "CASS") {
  }

  /**
   * @dev Throws if save is not active.
   */
  modifier saleIsOpen() {
    require(!PAUSE, "Sale must be active to mint");
    _;
  }

  /**
   * @dev Throws if save is not active.
   */
  modifier whitelistSaleIsOpen() {
    require(!WHITELISTPAUSE, "Sale for whitelist must be active to mint");
    _;
  }

  /**
   * @dev Set the max mint of whitelist
   */
  function setAllowListMaxMint(uint256 maxMint) external onlyOwner {
    whitelistMaxMint = maxMint;
  }

  /**
   * @dev Add the whitelist
   */
  function addToWhitelist(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "Null address");

      _whitelist[addresses[i]] = true;
    }
  }

  /**
   * @dev Remove the whitelist
   */
  function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      require(addresses[i] != address(0), "Null address");

      /// @dev We don't want to reset possible _whitelistClaimed numbers.
      _whitelist[addresses[i]] = false;
    }
  }

  /**
   * @dev Check the whitelist
   */
  function isWhitelist(address addr) external view returns (bool) {
    return _whitelist[addr];
  }

  /**
  * @dev Get the count of tokens in whitelist
  */
  function whitelistClaimedBy(address owner) external view returns (uint256){
    require(owner != address(0), 'Null address');

    return _whitelistClaimed[owner];
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    baseTokenURI = baseURI;
  }

  /**
   * @dev Mint regular assassin with count
   */
  function mintRegularTokens(uint256 _count) external payable saleIsOpen {
    address wallet = _msgSender();
    uint256 total = _tokenIdRegularTracker.current();

    // Set limit to mint per transaction
    require(_count > 0 && _count <= 3, "Max 3 NFTs per transaction");
    // Set max limit of regular assassins
    require(total + _count <= MAX_REGULAR_TOKENS, "Max limit of Regular");
    // Check the balance
    require(msg.value >= price(_count), "Not enough ETH for transaction");

    for (uint256 i = 0; i < _count; i++) {
      // Increase tracker and counter of regular assassin
      _tokenIdRegularTracker.increment();
      _regularTokenCounter += 1;

      // Mint regular assassin
      uint256 tokenId = _tokenIdRegularTracker.current();
      _safeMint(wallet, tokenId);

      emit welcomeToAssassin(tokenId);
    }
  }

  /**
   * @dev Mint regular assassin with count for whitelist
   */
  function mintRegularTokensWhiteList(uint256 _count) external payable saleIsOpen whitelistSaleIsOpen {
    address wallet = _msgSender();
    uint256 total = _tokenIdRegularTracker.current();

    // Check the white list
    require(_whitelist[wallet], 'Not the White List');
    // Set limit to mint per transaction
    require(_count > 0 && _count <= 3, "Max 3 NFTs per transaction");
    // Set max limit of regular assassins
    require(total + _count <= MAX_REGULAR_TOKENS, "Max limit of Regular");
    // Check the max mint of white list
    require(_whitelistClaimed[wallet] + _count <= whitelistMaxMint, 'Max allowed');
    // Check the balance
    require(msg.value >= price(_count), "Not enough ETH for transaction");

    for (uint256 i = 0; i < _count; i++) {
      // Increase tracker and counter of regular assassin
      _tokenIdRegularTracker.increment();
      _regularTokenCounter += 1;
      _whitelistClaimed[wallet] += 1;

      // Mint regular assassin
      uint256 tokenId = _tokenIdRegularTracker.current();
      _safeMint(wallet, tokenId);

      emit welcomeToAssassin(tokenId);
    }
  }

  /**
   * @dev Mint super assassin using 2 regular assassins
   */
  function mintSuperTokens(uint256 _tokenIdRegular1, uint256 _tokenIdRegular2) external saleIsOpen
  {
    address wallet = _msgSender();
    uint256 total = _tokenIdSuperTracker.current();

    // Check same tokens
    require(_tokenIdRegular1 != _tokenIdRegular2, "Same tokens");
    // Set max limit of super assassins
    require(total + 1 <= MAX_SUPER_TOKENS, "Max limit of Super");
    // Check the owner of regular assassin 1
    require(ownerOf(_tokenIdRegular1) == wallet && _tokenIdRegular1 > 0 && _tokenIdRegular1 <= MAX_REGULAR_TOKENS, "Not the owner of this token");
    // Check the owner of regular assassin 2
    require(ownerOf(_tokenIdRegular2) == wallet && _tokenIdRegular2 > 0 && _tokenIdRegular2 <= MAX_REGULAR_TOKENS, "Not the owner of this token");

    // Burn 2 regular assassins and decrease the count of regular assassins
    burn(_tokenIdRegular1);
    burn(_tokenIdRegular2);
    _regularTokenCounter -= 2;

    // Increase tracker and counter of super assassin
    _tokenIdSuperTracker.increment();
    _superTokenCounter += 1;

    // Mint super assassin
    uint256 tokenIdSuper = _tokenIdSuperTracker.current() + SUPER_START_AT;
    _safeMint(wallet, tokenIdSuper);

    emit welcomeToAssassin(tokenIdSuper);
  }

  /**
   * @dev Mint ultimate assassin using 1 super assassin and 1 regular assassin
   */
  function mintUltimateTokens(uint256 _tokenIdSuper, uint256 _tokenIdRegular) external saleIsOpen
  {
    address wallet = _msgSender();
    uint256 total = _tokenIdUltimateTracker.current();

    // Check same tokens
    require(_tokenIdSuper != _tokenIdRegular, "Same tokens");
    // Set max limit of super assassins
    require(total + 1 <= MAX_ULTIMATE_TOKENS, "Max limit of Ultimate");
    // Check the owner of super assassin
    require(ownerOf(_tokenIdSuper) == wallet && _tokenIdSuper > MAX_REGULAR_TOKENS && _tokenIdSuper <= MAX_REGULAR_TOKENS + MAX_SUPER_TOKENS, "Not the owner of this token");
    // Check the owner of regular assassin
    require(ownerOf(_tokenIdRegular) == wallet && _tokenIdRegular > 0 && _tokenIdRegular <= MAX_REGULAR_TOKENS, "Not the owner of this token");

    // Burn 1 regular assassin, 1 super assassin and decrease the count of regular and super assassin
    burn(_tokenIdSuper);
    burn(_tokenIdRegular);
    _regularTokenCounter -= 1;
    _superTokenCounter -= 1;

    // Increase tracker and counter of ultimate assassin
    _tokenIdUltimateTracker.increment();
    _ultimateTokenCounter += 1;

    // Mint ultimate assassin
    uint256 tokenIdUltimate = _tokenIdUltimateTracker.current() + ULTIMATE_START_AT;
    _safeMint(wallet, tokenIdUltimate);

    emit welcomeToAssassin(tokenIdUltimate);
  }

  // Function to withdraw all Ether from this contract.
  function withdraw() external onlyOwner {
    // send all Ether to owner
    // Owner can receive Ether since the address of owner is payable
    (bool success, ) = owner().call{value: address(this).balance}("");
    require(success, "Failed to send Ether");
  }

  function totalRegularToken() public view returns (uint256) {
    return _regularTokenCounter;
  }

  function totalSuperToken() public view returns (uint256) {
    return _superTokenCounter;
  }

  function totalUltimateToken() public view returns (uint256) {
    return _ultimateTokenCounter;
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev Set the sale active
   */
  function setPause(bool _pause) external onlyOwner {
    PAUSE = _pause;
    emit PauseEvent(PAUSE);
  }

  function isPaused() external view returns (bool) {
    return PAUSE;
  }

  function price(uint256 _count) public pure returns (uint256) {
    return PRICE.mul(_count);
  }

}