// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract XOASIS is ERC721Enumerable, Ownable {
  using Strings for uint256;

  string public baseURI;
  string public baseExtension = ".json";
  string public notRevealedURI;

  bool public publicOpen = false;
  bool public preOpen = false;
  bool public revealed = false;

  uint256 public maxSupply = 10000;
  uint256 public maxPreSale = 2000;
  uint256 public preSaledAmount;
  uint256 public prePrice = 0.123 ether;
  uint256 public publicPrice = 0.123 ether;
  uint256 public giftLimit = 200;
  uint256 public giftedAmount;
  uint256 public maxPerMint = 5;

  mapping(address => bool) private preMinted;

  address wallet1 = 0x7E0fF5672e79968dD055EaBeebD061FC811f3587;
  address wallet2 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;
  address wallet3 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;
  address wallet4 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;
  address wallet5 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;
  address wallet6 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;
  address wallet7 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;
  address wallet8 = 0x53260D713FCbFcDA05855E4F757Ee25b0F1D4bB8;

  constructor() ERC721('X-OASIS', 'XOASIS') {}

  function mint(uint256 amount) external payable {
    require(publicOpen, "Public sale is not open");
    require(amount > 0, "Must mint at least one token");
    require(amount <= maxPerMint, "Max mint 5 token each time");
    require(msg.value >= publicPrice * amount, "Insufficient ETH amount");
    uint256 supply = totalSupply();
    require(supply + amount <= maxSupply, "Purchase would exceed max supply");
    for (uint256 i = 0; i < amount; i++) {
        _safeMint(msg.sender, supply + i);
    }
  }

  function preMint(uint256 amount, bytes memory signature) external payable {
    require(preOpen, "Pre sale is not open");
    require(amount == 1, "only buy one token");
    require(msg.value >= prePrice * amount, "Insufficient ETH amount");
    uint256 supply = totalSupply();
    require(supply + amount <= maxSupply, "Purchase would exceed max supply");
    require(preSaledAmount + amount <= maxPreSale, "Pre sale would exceed max supply");
    address signerOwner = signatureWallet(msg.sender, signature);
    require(signerOwner == owner(), "Not authorized to pre mint");
    require(!preMinted[msg.sender], "Can not pre mint twice");
    preSaledAmount ++;
    preMinted[msg.sender] = true;
    _safeMint(msg.sender, supply+1);
  }

  function signatureWallet (
    address wallet, 
    bytes memory signature
    ) private pure returns (address){
      return ECDSA.recover(keccak256(abi.encode(wallet)), signature);
  }

  //for read
  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    
    if (revealed == false) {
      return notRevealedURI;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)) : "";
  }

  //onlyOwner
  function setPublicPrice(uint256 newPublicPrice) public onlyOwner {
    publicPrice = newPublicPrice;
  }

  function togglePublicSale() public onlyOwner {
    publicOpen = !publicOpen;
  }

  function setPrePrice(uint256 newPrePrice) public onlyOwner {
    prePrice = newPrePrice;
  }

  function togglePreSale() public onlyOwner {
    preOpen = !preOpen;
  }

  function setBaseURI(string memory newBaseURI) public onlyOwner {
    baseURI = newBaseURI;
  }

  function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
    notRevealedURI = _notRevealedURI;
  }

  function reveal() public onlyOwner() {
    revealed = true;
  }

  function gift(address to, uint256 amount) public onlyOwner {
    uint256 supply = totalSupply();
    require(amount > 0, "Gift at least one");
    require(supply + amount <= maxSupply, "Purchase would exceed max supply");
    require(amount + giftedAmount <= giftLimit, "Gift reserve exceeded with provided amount.");
    
    for(uint256 i; i < amount; i++){
      giftedAmount ++;
      _safeMint( to, supply + i );
    }
  }

  function withdrawAll() external onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "balance is 0.");
    payable(wallet1).transfer((balance * 125) / 1000);
    payable(wallet2).transfer((balance * 125) / 1000);
    payable(wallet3).transfer((balance * 125) / 1000);
    payable(wallet4).transfer((balance * 125) / 1000);
    payable(wallet5).transfer((balance * 125) / 1000);
    payable(wallet6).transfer((balance * 125) / 1000);
    payable(wallet7).transfer((balance * 125) / 1000);
    payable(wallet8).transfer((balance * 125) / 1000);
  }

  function withdraw(uint256 _amount) external onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "balance is 0.");
    require(balance > _amount, "balance must be superior to amount");
    payable(wallet1).transfer((_amount * 125) / 1000);
    payable(wallet2).transfer((_amount * 125) / 1000);
    payable(wallet3).transfer((_amount * 125) / 1000);
    payable(wallet4).transfer((_amount * 125) / 1000);
    payable(wallet5).transfer((_amount * 125) / 1000);
    payable(wallet6).transfer((_amount * 125) / 1000);
    payable(wallet7).transfer((_amount * 125) / 1000);
    payable(wallet8).transfer((_amount * 125) / 1000);
  }
}