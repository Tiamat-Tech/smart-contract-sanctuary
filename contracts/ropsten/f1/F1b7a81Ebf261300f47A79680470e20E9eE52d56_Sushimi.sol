// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Sushimi is ERC721Enumerable, Ownable {
  uint256 public constant SUSHIMI_PRICE = 70000000000000000; // 0.07 ETH
  uint256 public constant MAX_SUSHIMI_PURCHASE = 20;
  
  uint256 public sushimiReserve;
  uint256 public constant MAX_SUSHIMIS = 10000;

  string public baseURI;

  bool public saleIsActive = false;

  constructor(string memory _baseURI, uint256 _sushimiReserve) ERC721("Sushimi", "SHM") {
    baseURI = _baseURI;
    sushimiReserve = _sushimiReserve;
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
  function mintReservedSushimis(uint256 _amount, address _to) public onlyOwner {      
    require((totalSupply() + _amount) <= MAX_SUSHIMIS, "Mint would exceed max supply of Sushimis");
    require(_amount > 0 && _amount <= sushimiReserve, "Not enough reserve left for team");
  
    uint supply = totalSupply();
    for (uint i = 0; i < _amount; i++) {
        _safeMint(_to, supply + i);
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
    require((totalSupply() + _amount) <= MAX_SUSHIMIS, "Purchase would exceed max supply of Sushimis");
    require(msg.value >= SUSHIMI_PRICE * _amount, "Ether value sent is not correct");
    
    for(uint i = 0; i < _amount; i++) {
      uint mintIndex = totalSupply();
      if (totalSupply() < MAX_SUSHIMIS) {
        _safeMint(msg.sender, mintIndex);
      }
    }
  }
}