pragma solidity >=0.8.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MintSniperAIO is ERC721URIStorage{
  using Counters for Counters.Counter;
  Counters.Counter private currentID;

  bool public saleActive = false;

  uint256 public totalSupply = 1000000;
  uint256 public availableSupply = 1000000;
  uint256 public mintPrice = 40000000000000000;
  constructor() ERC721 ("MintSniperAIO", "MSAIO") {
    currentID.increment();

  }

  mapping(address => uint256[]) public tokenHolders;

  function mint(uint256 addr) public payable {
    require(saleActive == true, "Public Sale not active!");
    require(msg.value >= mintPrice, "No enough Eth supplied!");
    require(availableSupply > 0, "Not enough supply of tokens"); 

    _safeMint(msg.sender, currentID.current());
    currentID.increment();
    availableSupply = availableSupply - 1;
  }
  function openSale() public {
    saleActive = true;
  }

  function availableSupplyCount() public view returns (uint256){
    return availableSupply;
  }

  function totalSupplyCount() public view returns (uint256){
    return totalSupply;
  }

  function closeSale() public {
    saleActive = false;
  }

}