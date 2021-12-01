// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";


contract NFT is ERC721, PaymentSplitter {
  using Strings for uint256;
  using Address for address;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  address[] private _distributions = [
    0x6f52aB9EFF44FBd2D99EC8d73dcb59DEfA049970,
    0x22E38368DDacc3C5D2cd11ecbbcf7E46E0F54715,
    0x007b37216E448B45F7bd49608F4C6028B9d1C140
  ];

  uint[] private _Shares = [
    94,
    3,
    3
  ];

  uint public constant maxSupply = 3333;
  uint public constant whitelistSpots = 1200;
  uint public constant price = 0.1 ether;
  uint public constant reservedAmount = 100; 
  uint public constant maxMintsPerAddressPublicSale = 3;
  uint public constant maxMintsPerAddressPreSale = 2;
  uint public reservedMintedAlready;

  bool public presaleOpen = false;
  bool public saleOpen = false;

  string public baseUri = ""; 
  string public baseExtension = ".json"; 
  
  mapping(address => uint) public mintsByAddressPublicSale;
  mapping(address => uint) public whitelist;

  event Minted(address minter, uint tokenID);

  constructor() 
    ERC721("NFT Collection", "ttt")
    PaymentSplitter(_distributions, _Shares) {
    }                                           // TODO change to final name

  modifier onlyEOA() {
    require(msg.sender == tx.origin, "Only EOA");
    _;
  }

  modifier onlyTeam() {
    require(
      msg.sender == 0x6f52aB9EFF44FBd2D99EC8d73dcb59DEfA049970 || 
      msg.sender == 0x22E38368DDacc3C5D2cd11ecbbcf7E46E0F54715 || 
      msg.sender == 0x007b37216E448B45F7bd49608F4C6028B9d1C140 ,
      "access forbidden");
    _;
  }

  function addToWhitelist(address[] memory addresses) external onlyTeam {
    for(uint256 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = maxMintsPerAddressPreSale;
    }
  }

  function mintSale(uint amount) external payable onlyEOA {
    require(saleOpen , "Sale not open yet");
    require(totalSupply() + amount <= maxSupply - (reservedAmount - reservedMintedAlready), "Max Supply reached");
    require(mintsByAddressPublicSale[msg.sender] + amount <= maxMintsPerAddressPublicSale, "Address already minted");
    require(msg.value == price * amount , "Incorrect price sent");
    mintsByAddressPublicSale[msg.sender] += amount;
    _mintToken(msg.sender, amount);
  }
  
  function mintReserved(address receiver, uint amount) external onlyTeam {
    require(totalSupply() + amount <= maxSupply, "Max Supply reached");
    require(reservedMintedAlready + amount <= reservedAmount, "Reserved Max reached");
    reservedMintedAlready += amount;
    _mintToken(receiver, amount);
  }

  function mintWhitelist(uint amount) external payable onlyEOA {
    require(presaleOpen , "Sale not open yet");
    require(totalSupply() + amount <= maxSupply - (reservedAmount - reservedMintedAlready), "Max Supply reached");
    require(whitelist[msg.sender] - amount >= 0, "Address already minted");
    require(msg.value == price * amount , "Incorrect price sent");
    whitelist[msg.sender] -= amount;
    _mintToken(msg.sender, amount);
  }

  function _mintToken(address to, uint amount) private {
    uint id;
    for(uint i = 0; i < amount; i++){
      _tokenIds.increment();
      id = _tokenIds.current();
      _mint(to, id);
      emit Minted(msg.sender, id);
    }
  }

  function setBaseExtension(string memory newBaseExtension) external onlyTeam {
    baseExtension = newBaseExtension;
  }

  function setBaseUri(string memory newBaseUri) external onlyTeam {
    baseUri = newBaseUri;
  }

  function switchSaleState() external onlyTeam {
    saleOpen = !saleOpen;
  }

  function switchWhitelistSaleState() external onlyTeam {
    presaleOpen = !presaleOpen;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string memory _tokenURI = "Token with that ID does not exist.";
    if (_exists(tokenId)){
      _tokenURI = string(abi.encodePacked(baseUri, tokenId.toString(),  baseExtension));
    }
    return _tokenURI;
  }
  
  function totalSupply() public view returns(uint){
    return _tokenIds.current();
  }

  function withdrawAll() external onlyTeam{
    for (uint256 i = 0; i < _distributions.length; i++) {
      release(payable(_distributions[i]));
    }
  }
}