// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

contract Sushimi is ERC721Enumerable, IERC2981, Ownable {
  uint256 public sushimiPrice = 70000000000000000; // 0.07 ETH
  uint256 public constant MAX_SUSHIMI_PURCHASE = 20;
  
  uint256 public sushimiReserve;
  uint256 public constant MAX_SUSHIMIs = 10000;

  string public baseURI;
  string public contractURI = "";

  bool public saleIsActive = false;

  uint256 public constant MAX_ROYALTIES_PERCENTAGE = 10;
  uint256 public royaltiesPercentage = 10;

  constructor(string memory _baseURI, uint256 _sushimiReserve, uint256 _sushimiPrice) ERC721("Sushimi", "SHM") {
    baseURI = _baseURI;
    sushimiReserve = _sushimiReserve;
    sushimiPrice = _sushimiPrice;
  }

  // ERC2981
  function royaltyInfo(uint256, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
    uint256 royalties = (_salePrice * royaltiesPercentage) / 100;
    return (owner(), royalties);
  }

  // Add royalties interface
  function supportsInterface(bytes4 interfaceId) public view override(IERC165, ERC721Enumerable) returns (bool) {
    return interfaceId == type(IERC2981).interfaceId ||
    super.supportsInterface(interfaceId);
  }

  // Sets the royalty percentage
  function setRoyaltyPercentage(uint256 _newPercentage) public onlyOwner {
    require(_newPercentage <= MAX_ROYALTIES_PERCENTAGE, "New percentage is too high");
    
    royaltiesPercentage = _newPercentage;
  }

  // Sets the ContracURI
  function setContractURI(string calldata _contractURI) public onlyOwner {
    contractURI = _contractURI;
  }

  // Returns the tokens tokenURI
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    if(!_exists(_tokenId)) return "";
    return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
  }

  // Withdraw funds
  function withdraw() public onlyOwner {
    uint balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }

  // Mint Sushimis for giveaways
  function mintReservedSushimis(uint256 _amount) public onlyOwner {      
    require((totalSupply() + _amount) <= MAX_SUSHIMIs, "Mint would exceed max supply of Sushimis");
    require(_amount > 0 && _amount <= sushimiReserve, "Not enough reserve left for team");
  
    uint supply = totalSupply();
    for (uint i = 0; i < _amount; i++) {
        _safeMint(msg.sender, supply + i);
    }
    sushimiReserve = sushimiReserve - _amount;
  }

  // Flip the sale state
  function flipSaleState() public onlyOwner {
    saleIsActive = !saleIsActive;
  }

  // Mint Sushimis
  function mintSushimi(uint _amount) public payable {
    require(saleIsActive, "Sale must be active to mint Sushimis");
    require(_amount > 0 && _amount <= MAX_SUSHIMI_PURCHASE, "Can only mint 20 tokens at a time");
    require((totalSupply() + _amount) <= MAX_SUSHIMIs, "Purchase would exceed max supply of Sushimis");
    require(msg.value >= sushimiPrice * _amount, "Ether value sent is not correct");
    
    for(uint i = 0; i < _amount; i++) {
      uint mintIndex = totalSupply();
      if (totalSupply() < MAX_SUSHIMIs) {
        _safeMint(msg.sender, mintIndex);
      }
    }
  }
}