// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RobotNinja is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
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

  string public baseTokenURI;
  bool private PAUSE = true;
  Counters.Counter private _tokenIdRegularTracker;
  Counters.Counter private _tokenIdSuperTracker;
  Counters.Counter private _tokenIdUltimateTracker;
  Counters.Counter private _counter;

  event PauseEvent(bool pause);
  event welcomeToNinja(uint256 indexed id);

  constructor() ERC721("RobotNinja", "RobotNinja") {
  }

  modifier saleIsOpen() {
    require(!PAUSE, "Sale must be active to mint");
    _;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    baseTokenURI = baseURI;
  }

  function mintRegularTokens(uint256 _count) external payable saleIsOpen {
    address wallet = _msgSender();
    uint256 total = totalRegularToken();

    require(_count > 0 && _count <= 3, "Max 3 NFTs per transaction");
    require(total + _count <= MAX_REGULAR_TOKENS, "Max limit of Regular");
    require(msg.value >= price(_count), "Not enough ETH for transaction");

    for (uint256 i = 0; i < _count; i++) {
      _tokenIdRegularTracker.increment();
      _counter.increment();

      uint256 tokenId = totalRegularToken();
      _safeMint(wallet, tokenId);

      emit welcomeToNinja(tokenId);
    }
  }

  function mintSuperTokens(uint256 _tokenIdRegular1, uint256 _tokenIdRegular2) external saleIsOpen
  {
    address wallet = _msgSender();
    uint256 total = totalSuperToken();

    require(total + 1 <= MAX_SUPER_TOKENS, "Max limit of Super");
    require(ownerOf(_tokenIdRegular1) == wallet && _tokenIdRegular1 > 0 && _tokenIdRegular1 <= MAX_REGULAR_TOKENS, "Not the owner of this token");
    require(ownerOf(_tokenIdRegular2) == wallet && _tokenIdRegular2 > 0 && _tokenIdRegular2 <= MAX_REGULAR_TOKENS, "Not the owner of this token");

    burn(_tokenIdRegular1);
    burn(_tokenIdRegular2);

    _counter.decrement();
    _tokenIdSuperTracker.increment();

    uint256 tokenIdSuper = totalSuperToken() + SUPER_START_AT;

    _safeMint(wallet, tokenIdSuper);

    emit welcomeToNinja(tokenIdSuper);
  }

  function mintUltimateTokens(uint256 _tokenIdSuper, uint256 _tokenIdRegular) external saleIsOpen
  {
    address wallet = _msgSender();
    uint256 total = totalUltimateToken();

    require(total + 1 <= MAX_ULTIMATE_TOKENS, "Max limit of Ultimate");
    require(ownerOf(_tokenIdSuper) == wallet && _tokenIdSuper > MAX_REGULAR_TOKENS && _tokenIdSuper <= MAX_REGULAR_TOKENS + MAX_SUPER_TOKENS, "Not the owner of this token");
    require(ownerOf(_tokenIdRegular) == wallet && _tokenIdRegular > 0 && _tokenIdRegular <= MAX_REGULAR_TOKENS, "Not the owner of this token");

    burn(_tokenIdSuper);
    burn(_tokenIdRegular);

    _counter.decrement();
    _tokenIdUltimateTracker.increment();

    uint256 tokenIdUltimate = totalUltimateToken() + ULTIMATE_START_AT;

    _safeMint(wallet, tokenIdUltimate);

    emit welcomeToNinja(tokenIdUltimate);
  }

  // Function to withdraw all Ether from this contract.
  function withdraw() external onlyOwner {
    // send all Ether to owner
    // Owner can receive Ether since the address of owner is payable
    (bool success, ) = owner().call{value: address(this).balance}("");
    require(success, "Failed to send Ether");
  }

  function totalRegularToken() public view returns (uint256) {
    return _tokenIdRegularTracker.current();
  }

  function totalSuperToken() public view returns (uint256) {
    return _tokenIdSuperTracker.current();
  }

  function totalUltimateToken() public view returns (uint256) {
    return _tokenIdUltimateTracker.current();
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
      super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function setPause(bool _pause) public onlyOwner {
    PAUSE = _pause;
    emit PauseEvent(PAUSE);
  }

  function price(uint256 _count) public pure returns (uint256) {
    return PRICE.mul(_count);
  }

  function getUnsoldTokens(uint256 offset, uint256 limit) external view returns (uint256[] memory){
    uint256[] memory tokens = new uint256[](limit);

    for (uint256 i = 0; i < limit; i++) {
      uint256 key = i + offset;
      if(ownerOf(key) == address(0)){
        tokens[i] = key;
      }
    }

    return tokens;
  }

}