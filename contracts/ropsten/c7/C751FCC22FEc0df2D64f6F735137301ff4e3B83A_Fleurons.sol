// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Base64.sol";
import "./Colors.sol";

contract Fleurons is ERC721, ERC721Enumerable, Ownable {
  using Counters for Counters.Counter;
  using Colors for Colors.Color;
  using Strings for uint256;

  uint256 public constant MAX_CRANES_PER_YEAR = 1000;
  string public constant DESCRIPTION = "A fleuron is a typographic element, or glyph, used either as a punctuation mark or as an ornament for typographic compositions.";

  uint256 public price = 0.02 ether;

  Counters.Counter private _tokenIdCounter;
  mapping(uint256 => Counters.Counter) private _yearlyCounts;
  mapping(uint256 => uint256[3]) private _seeds;

  constructor() ERC721("Fleurons", "CRNS") {}

  function _mint(address destination) private {
    require(currentYearTotalSupply() <= MAX_CRANES_PER_YEAR, "YEARLY_MAX_REACHED");

    uint256 tokenId = _tokenIdCounter.current();
    uint256 destinationSeed = uint256(uint160(destination)) % 10000000;

    _safeMint(destination, tokenId);

    uint256 year = getCurrentYear();
    _yearlyCounts[year].increment();
    uint256 yearCount = _yearlyCounts[year].current();
    _seeds[tokenId][0] = year;
    _seeds[tokenId][1] = yearCount;
    _seeds[tokenId][2] = destinationSeed;

    _tokenIdCounter.increment();
  }

  function mint(address destination) public onlyOwner {
    _mint(destination);
  }

  function craftForSelf() public payable virtual {
    require(msg.value >= price, "PRICE_NOT_MET");
    _mint(msg.sender);
  }

  function craftForFriend(address walletAddress) public payable virtual {
    require(msg.value >= price, "PRICE_NOT_MET");
    _mint(walletAddress);
  }

  function setPrice(uint256 newPrice) public onlyOwner {
    price = newPrice;
  }

  function getCurrentYear() private view returns (uint256) {
    return 1970 + block.timestamp / 31556926;
  }

  function getCount() public view returns (uint256) {
    uint256 year = getCurrentYear();
    uint256 count = _yearlyCounts[year].current();
    return count;
  }

  function currentYearTotalSupply() public view returns (uint256) {
    return _yearlyCounts[getCurrentYear()].current();
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    uint256[3] memory seed = _seeds[tokenId];
    string memory year = seed[0].toString();
    string memory count = seed[1].toString();
    string memory colorSeed = string(abi.encodePacked(seed[0], seed[1], seed[2]));

    string memory c0seed = string(abi.encodePacked(colorSeed, "COLOR0"));
    Colors.Color memory base = Colors.fromSeedWithMinMax(c0seed, 0, 359, 20, 100, 30, 40);
    uint256 hMin = base.hue + 359 - Colors.valueFromSeed(c0seed, 5, 60);
    uint256 hMax = base.hue + 359 + Colors.valueFromSeed(c0seed, 5, 60);
    string memory c0 = base.toHSLString();
    string memory c1 = Colors.fromSeedWithMinMax(string(abi.encodePacked(colorSeed, "COLOR1")), hMin, hMax, 70, 90, 70, 85).toHSLString();
    string memory bg = Colors.fromSeedWithMinMax(string(abi.encodePacked(colorSeed, "BACKGROUND")), 0, 359, 0, 50, 10, 100).toHSLString();

    string[10] memory parts;

    parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500" style="enable-background:new 0 0 500 500" xml:space="preserve"><path style="fill:';
    parts[1] = bg;
    parts[2] = '" d="M0 0h500v500H0z"/>';
    parts[3] = '<path d="M278.4 243.2c-1.7.2-4.2.3-7.6.3-8.6 0-19.3-2.7-32.1-8.2 5.3 6.9 7.9 15.5 7.9 25.8 0 2.5-.2 5-.5 7.4-.3 2.4-.6 4.4-.9 6-.3 1.6-.5 2.5-.5 2.7.8 0 2.6.3 5.2.9 2.6.6 6.4 2.4 11.3 5.2 4.9 2.8 9.5 6.5 13.7 10.9 4.2 4.4 7.9 11 11 19.9 3.2 8.8 4.7 18.9 4.7 30.2 0 10.9-2.5 21.2-7.4 30.7-4.9 9.6-10.4 17.1-16.4 22.7-6 5.6-11.9 11.2-17.6 17-5.8 5.8-9.2 10.6-10.2 14.3-1.7-3.8-5.5-8.7-11.5-14.7s-11.9-11.8-17.8-17.3-11.2-13.1-15.9-22.5c-4.7-9.4-7.1-19.5-7.1-30.2 0-11.3 1.5-21.4 4.6-30.1 3-8.7 6.8-15.3 11.2-19.8 4.4-4.5 8.8-8.2 13.2-11 4.4-2.8 8.1-4.7 11-5.5l4.7-.9c1.9-3.8 2.8-8.6 2.8-14.5 0-10.7-3.8-20.3-11.3-28.7-7.6-8.4-18.2-12.6-31.8-12.6-18.3 0-34 6.9-47.3 20.8-15.3 16.2-23 34.4-23 54.8v5.7l.3.9H91.3c0-29.4 10.9-55 32.8-76.9 10.7-10.7 30.3-24.3 58.8-40.6s47.1-29 55.9-37.8c14.1-14.1 21.1-31 21.1-50.7 0-1-.1-2-.2-3-.1-.9-.2-1.7-.2-2.4v-.6l31.2.3c0 9.4-2.3 21-6.9 34.7-4.6 13.7-12.8 26.1-24.6 37.2-6.9 6.5-15 12.7-24.3 18.4-9.2 5.8-19.6 11.6-31 17.3-11.4 5.8-17.9 9.1-19.4 9.9 2.9-.6 5.3-.9 6.9-.9 10.7 0 24.3 3.9 40.8 11.7 16.5 7.8 29.3 11.7 38.6 11.7 1.5 0 3.9-.2 7.2-.6.2-1.1.6-2.5 1.1-4.4.5-1.9 2.3-5.2 5.2-10.1 2.9-4.8 6.6-9 11-12.6 4.4-3.6 11-6.9 19.8-9.9s18.9-4.6 30.3-4.6c10.7 0 20.8 2.2 30.2 6.6s17 9.3 22.5 14.8c5.6 5.5 11.3 11 17.3 16.7 6 5.7 10.9 9.2 14.7 10.7-3.4.8-7.2 3.2-11.3 7.1-4.2 3.9-8.6 8.1-13.1 12.6s-9.6 9-15.1 13.6c-5.6 4.5-12.3 8.3-20.2 11.3-7.9 3.1-16.2 4.6-25 4.6-8.4 0-16.1-.8-23-2.4-6.9-1.6-12.7-3.7-17.2-6.3-4.5-2.6-8.5-5.5-11.8-8.7-3.4-3.2-5.9-6.3-7.7-9.4-1.8-3.2-3.3-6-4.4-8.7-1.2-2.6-1.9-4.7-2.4-6.1l-.5-2.7z" style="fill:';
    parts[4] = c0;
    parts[5] = '">';
    parts[6] = '<animateTransform attributeName="transform" type="translate" values="0 -10;0 10;0 -10" dur="5s" repeatCount="indefinite" /></path></svg>';

    string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6]));
    output = Base64.encode(bytes(string(abi.encodePacked('{"name":"Fleuron #', year, "/", count, '","description":"', DESCRIPTION, '","image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
    output = string(abi.encodePacked("data:application/json;base64,", output));

    return output;
  }

  function withdrawAll() public payable onlyOwner {
    require(payable(msg.sender).send(address(this).balance));
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  // The following functions are overrides required by Solidity.
  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}