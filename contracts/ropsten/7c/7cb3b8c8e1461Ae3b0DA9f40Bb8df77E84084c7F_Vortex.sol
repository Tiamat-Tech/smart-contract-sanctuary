// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Vortex is ERC721Enumerable, Ownable {
  using SafeMath for uint256;
  using Strings for uint256;

  uint8 private MAX_GIFT_COUNT = 100;
  uint8 private MAX_MINT = 5;
  uint256 private PRICE = 0.08 ether;
  uint8 private _giftCount = 0;
  uint256 private _maxSupply;

  string private _tokenBaseURI;
  string private _defaultBaseURI;

  mapping(address => bool) public whitelist;
  mapping(address => uint8) public presaleNumPerAddress;

  bool public locked;
  bool public bigBang;
  bool public presaleLive;
  bool public revealed;

  event NameGiven(uint256 indexed tokenId, string name);
  event StoryGiven(uint256 indexed tokenId, string story);

  /**
   * @dev Throws if called when BigBang has not happened yet
   */
  modifier alreadyRevealed() {
    require(revealed, "Wait for reveal!");
    _;
  }

  /**
   * @dev Throws if called when method is locked for usage
   */
  modifier notLocked() {
    require(!locked, "Methods are locked");
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _uri,
    uint256 _max
  ) ERC721(_name, _symbol) {
    _tokenBaseURI = _uri;
    _maxSupply = _max;
  }

  function setBaseURI(string calldata _newUri) external onlyOwner notLocked {
    _tokenBaseURI = _newUri;
  }

  function setDefaultBaseURI(string calldata _newUri) external onlyOwner {
    _defaultBaseURI = _newUri;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721)
    returns (string memory)
  {
    require(_exists(tokenId), "Cannot query non-existent token");

    return
      bytes(_tokenBaseURI).length > 0
        ? string(abi.encodePacked(_tokenBaseURI, tokenId.toString()))
        : _defaultBaseURI;
  }

  function lock() external onlyOwner {
    locked = true;
  }

  function executeBigBang() external onlyOwner {
    bigBang = !bigBang;
  }

  function togglePresale() external onlyOwner {
    presaleLive = !presaleLive;
  }

  function toggleReveal() external onlyOwner {
    revealed = !revealed;
  }

  function setName(uint256 _tokenId, string memory _name)
    external
    alreadyRevealed
  {
    require(_exists(_tokenId), "Cannot update non-existent token");
    require(ownerOf(_tokenId) == msg.sender, "You don't own this General!");
    emit NameGiven(_tokenId, _name);
  }

  function setStory(uint256 _tokenId, string memory _story)
    external
    alreadyRevealed
  {
    require(_exists(_tokenId), "Cannot update non-existent token");
    require(ownerOf(_tokenId) == msg.sender, "You don't own this General!");
    emit StoryGiven(_tokenId, _story);
  }

  /**
   * @dev Gift Generals to provided addresses.
   * @param _recipients List of addresses that will receive General
   */
  function gift(address[] memory _recipients) external onlyOwner {
    require(
      _giftCount + _recipients.length <= MAX_GIFT_COUNT,
      "Max gift limit Reached!"
    );
    require(
      totalSupply().add(_recipients.length) <= _maxSupply,
      "All Generals are sold out. Sorry!"
    );
    for (uint256 i = 0; i < _recipients.length; i++) {
      _mint(_recipients[i], totalSupply() + 1);
      _giftCount = _giftCount + 1;
    }
  }

  /**
   * @dev Presale Mint to msg.sender. Only whitelisted addresses can use it
   * @param _num Quantity to mint
   */
  function presale(uint8 _num) external payable {
    require(presaleLive, "Presale has not yet started.");
    require(whitelist[msg.sender], "You're not on the whitelist.");
    require(
      _num <= presaleNumPerAddress[msg.sender],
      "Can't purchase more than allowed presale Generals"
    );
    require(
      msg.value == uint256(_num).mul(PRICE),
      "You need to pay the required price."
    );
    _mintTokens(_num);
    presaleNumPerAddress[msg.sender] = presaleNumPerAddress[msg.sender] - _num;
  }

  /**
   * @dev Mint to msg.sender.
   * @param _num addresses of the future owner of the token
   */
  function mint(uint8 _num) external payable {
    require(bigBang, "Wait for BigBang!");
    require(
      totalSupply().add(uint256(_num)) <= _maxSupply,
      "All Generals are sold out. Sorry!"
    );
    require(_num <= MAX_MINT, "Max mint limit breached!");
    require(
      msg.value == uint256(_num).mul(PRICE),
      "You need to pay the required price."
    );
    _mintTokens(_num);
  }

  /**
   * @dev Helper function to mint list of tokens
   */
  function _mintTokens(uint8 _num) private {
    for (uint8 i = 0; i < _num; i++) {
      _mint(msg.sender, totalSupply() + 1);
    }
  }

  function withdraw() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  /**
   * @dev Add addresses from Whitelist2
   * @param addresses Addresses
   */
  function addToWhitelist2(address[] memory addresses) public onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = true;
      presaleNumPerAddress[addresses[i]] = 2;
    }
  }

  /**
   * @dev Add addresses from Whitelist3
   * @param addresses Addresses to be removed
   */
  function addToWhitelist3(address[] memory addresses) public onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = true;
      presaleNumPerAddress[addresses[i]] = 3;
    }
  }

  /**
   * @dev Remove addresses from whitelist
   * @param addresses Addresses to be removed
   */
  function removeFromWhitelist(address[] memory addresses) public onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = false;
      presaleNumPerAddress[addresses[i]] = 0;
    }
  }
}