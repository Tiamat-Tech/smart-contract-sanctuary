//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
contract NFT is ERC721PresetMinterPauserAutoId {
  
  string greeting = "aaaa";
  constructor() ERC721PresetMinterPauserAutoId("NFT Survey Proto", "NFTSP", "https://asia-northeast1-nft-survey.cloudfunctions.net/api/v1/tokens/") {}
  
  address owner = 0x5601613b1D2871ed28E3Af31AC9E41DC4A4e8016;
  uint public price = 1 wei;
  mapping(uint => bool) public minted;
  mapping(address => uint)public hadTokens;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
  }

  function mintNFT(uint256 _nftid) public payable {
    require(msg.value == getPrice() );
    require( _nftid <= 10000);
    _safeMint( msg.sender , _nftid);
    minted[_nftid] = true;
    hadTokens[msg.sender]++;
  }

  function getPrice() public view returns(uint)
  {
    return price;
  }

  function setPrice(uint _price) public onlyOwner
  {
    console.log("Changing price from '%s' to '%s'", price, _price);
    price = _price;
  }

  function getHowManyToken(address _owner)public view returns(uint)
  {
    uint tokens = hadTokens[_owner];
    return tokens;
  } 

  function withDrawSeparate(address f,address s) public onlyOwner
  {
    uint halfbalance = address(this).balance/2;
    payable(f).transfer(halfbalance);
    payable(s).transfer(halfbalance);
  }

  function greet() public view returns (string memory) {
    return greeting;
  }
  
  function setGreeting(string memory _greeting) public {
    console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
    greeting = _greeting;
  }
}