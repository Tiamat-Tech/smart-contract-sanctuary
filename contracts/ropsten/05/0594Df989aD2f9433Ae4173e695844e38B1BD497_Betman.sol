// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Betman is ERC721Enumerable, Ownable {
  string public PROVENANCE;
  bool public publicsaleIsActive = false;
  bool public whitelistIsActive = false;
  string private baseURI;

  uint256 public constant MAX_SUPPLY = 500;
  uint256 public constant MAX_MINT = 2;
  uint256 public constant WHITE_MINT_PRICE = 50000000000000000; // mint price: 0.05 eth
  uint256 public constant PUBLIC_MINT_PRICE = 80000000000000000; // mint price: 0.08 eth


  mapping(address => uint8) private _whiteList;

  constructor(
    string memory name, 
    string memory symbol
  ) ERC721(name, symbol) {
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function setbaseURI(string memory baseURI_) external onlyOwner() {
    baseURI = baseURI_;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function flippublicsale(bool newState) public onlyOwner() {
    publicsaleIsActive = newState;
  }

  function saleIsActive() public view returns (bool) {
    return publicsaleIsActive;
  }

  function flipwhitesale(bool newState) public onlyOwner() {
    whitelistIsActive = newState;
  }

  function whiteIsActive() public view returns (bool) {
    return whitelistIsActive;
  }

  function setProvenance(string memory provenance) public onlyOwner() {
    PROVENANCE = provenance;
  }

  function nwhiteMint(address addr) external view returns (uint8) {
     return _whiteList[addr];
  }

  function setWhiteList(address[] calldata addresses) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      _whiteList[addresses[i]] = 2;
    }
  }

  function mintWhiteList(uint8 numberOfTokens) external payable {
    uint totalToken = totalSupply();
    require(whitelistIsActive, "White list is not active");
    require(numberOfTokens <= _whiteList[msg.sender], "Exceed available tokens");
    require(totalToken + numberOfTokens <= 150, "Exceed white list maximum mint");
    require(WHITE_MINT_PRICE * numberOfTokens <= msg.value, "Ether value is insufficient");
    
    _whiteList[msg.sender] -= numberOfTokens;
    for (uint256 i = 0; i < numberOfTokens; i++) {
      _safeMint(msg.sender, totalToken + i);
    }
  }
  
  function mint(uint256 numberOfTokens) public payable {
    uint256 totalToken = totalSupply();
    require(publicsaleIsActive, "Sale must be active to mint tokens");
    require(numberOfTokens > 0, "Number is positive");
    require(numberOfTokens <= MAX_MINT, "Number of mint exceed MAX_MINT");
    require(totalToken + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed token supply");
    require(PUBLIC_MINT_PRICE * numberOfTokens <= msg.value, "Ether value is insufficient");

    for (uint256 i = 0; i < numberOfTokens; i++) {
      _safeMint(msg.sender, totalToken + i);
    }
  }

  function reserve() public onlyOwner {
    uint supply = totalSupply();
    uint i;
    for (i = 0; i < 25; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }

  function withdraw() public onlyOwner {
    uint balance = address(this).balance;
    Address.sendValue(payable(owner()), balance);
  }
}