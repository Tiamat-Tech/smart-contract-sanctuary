// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./ERC721A.sol";

contract Xoasis is ERC721A, Ownable, ReentrancyGuard {
  string public baseURI;

  bool public preSaleOpen = false;
  bool public publicSaleOpen = false;

  uint256 public maxSupplyAmount = 11111;
  uint256 public preSalePrice = 0.18 ether;
  uint256 public publicSalePrice = 0.2 ether;

  uint8 public maxPreSaleMint = 1;
  uint8 public maxPublicSaleMint = 5;

  //pre sale minted
  mapping (address => bool) private preSaleMinted;

  //public sale minted
  mapping (address => uint256) private publicSaleMinted;


  constructor() ERC721A("Xoasis", "XOASIS", 6, 11111) {}

  modifier contractVerify() {
    require(tx.origin == msg.sender, "THE CALLER CANT BE A CONTRACT");
    _;
  }

  //mint
  function preSaleMint() external payable contractVerify {
    require(preSaleOpen, "XOASIS PRE SALE HAS NOT OPEN YET");
    require(!isPreMinted(msg.sender), "SORRY, ONLY ONE CHANCE");
    require(totalSupply() + maxPreSaleMint <= maxSupplyAmount, "REACHED MAX SUPPLY AMOUNT");
    require(msg.value >= maxPreSaleMint * preSalePrice, "INSUFFICIENT ETH AMOUNT");
    if (msg.value > maxPreSaleMint * preSalePrice) {
      payable(msg.sender).transfer(msg.value - maxPreSaleMint * preSalePrice);
    }
    _safeMint(msg.sender, maxPreSaleMint);
    preSaleMinted[msg.sender] = true;
  }

  function publicSaleMint(uint256 amount) external payable contractVerify {
    require(publicSaleOpen, "XOASIS PUBLIC SALE HAS NOT OPEN YET");
    require(amount <= maxPublicSaleMint, "EXCEEDS MAX PUBLIC SALE MINT");
    require(totalSupply() + amount <= maxSupplyAmount, "REACHED MAX SUPPLY AMOUNT");
    uint256 mintedAmount = publicAmountMinted(msg.sender);
    require(mintedAmount + amount <= maxPublicSaleMint, "EXCEEDS MAX PUBLIC SALE MINT");
    require(msg.value >= amount * publicSalePrice, "INSUFFICIENT ETH AMOUNT");
    if (msg.value > amount * publicSalePrice) {
      payable(msg.sender).transfer(msg.value - amount * publicSalePrice);
    }
    _safeMint(msg.sender, amount);
    publicSaleMinted[msg.sender] = mintedAmount + amount;
  }

  function giftMint(address xer, uint256 amount) external onlyOwner {
    require(amount > 0, "GIFT AT LEAST ONE");
    require(amount + totalSupply() <= maxSupplyAmount, "REACHED MAX SUPPLY AMOUNT");
    _safeMint(xer, amount);
  }

  //read
  function isPreMinted(address owner) public view returns (bool) {
    require(owner != address(0), "ERC721A: number minted query for the zero address");
    return preSaleMinted[owner];
  }

  function publicAmountMinted(address owner) public view returns (uint256) {
    require(owner != address(0), "ERC721A: number minted query for the zero address");
    return publicSaleMinted[owner];
  }

  function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  //setting
  function togglePreSale() external onlyOwner {
    preSaleOpen = !preSaleOpen;
  }

  function togglePublicSale() external onlyOwner {
    publicSaleOpen = !publicSaleOpen;
  }

  function setBaseURI(string memory newBaseURI) external onlyOwner {
    baseURI = newBaseURI;
  }

  function setPreSalePrice(uint256 newPreSalePrice) external onlyOwner {
    preSalePrice = newPreSalePrice;
  }

  function setPublicSalePrice(uint256 newPublicSalePrice) external onlyOwner {
    publicSalePrice = newPublicSalePrice;
  }

  //withdraw
  address private wallet1 = 0x7E0fF5672e79968dD055EaBeebD061FC811f3587;
  address private wallet2 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;

  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "NOT ENOUTH BALANCE TO WITHDRAW");

    payable(wallet1).transfer(balance/2);
    payable(wallet2).transfer(balance/2);
  }
}