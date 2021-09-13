pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SecretSantaTest is ERC721, Ownable {

  using SafeMath for uint256;

  uint256 public price = 40000000000000000; // 0.04 ETH

  uint256 public MAX_TOKENS = 10111;

  uint256 public MAX_TOKEN_PURCHASE = 10;
  
  bool public saleIsActive = false;

  mapping (address => bool) public whitelist;

  constructor() ERC721("Secret Santa Test", "SANTA") {
    _setBaseURI("https://secret-santa-dapp.herokuapp.com/tokens/");
  }
  
  function addToWhitelist(address addr) public onlyOwner {
    whitelist[addr] = true;
  }
  
  function addListToWhitelist(address[] memory addrs) public onlyOwner {
    for (uint i = 0; i < addrs.length; i++) {
      whitelist[addrs[i]] = true;
    }
  }

  function deleteFromWhitelist(address addr) public onlyOwner {
    whitelist[addr] = false;
  }

  function withdraw() public onlyOwner {
    uint balance = address(this).balance;
    msg.sender.transfer(balance);
  }

  function flipSaleState() public onlyOwner {
    saleIsActive = !saleIsActive;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    _setBaseURI(baseURI);
  }   

  function setPrice(uint _price) public onlyOwner {
    price = _price;
  }

  function mint(uint numberOfTokens) public payable {
    require(whitelist[msg.sender] || saleIsActive, "Address must be whitelisted OR Sale must be active to mint Tokens");
    require(numberOfTokens <= MAX_TOKEN_PURCHASE, "Can only mint 10 tokens at a time");
    require(totalSupply().add(numberOfTokens) <= MAX_TOKENS, "Purchase would exceed max supply of Tokens");
    require(msg.value >= price.mul(numberOfTokens), "Ether value sent is not correct");

    for(uint i = 0; i < numberOfTokens; i++) {
      uint256 mintIndex = totalSupply();
      if (totalSupply() < MAX_TOKENS) {
	_safeMint(msg.sender, mintIndex);
      }
    }
  }

}