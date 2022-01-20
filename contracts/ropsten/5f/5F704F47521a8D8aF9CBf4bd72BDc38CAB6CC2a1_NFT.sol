pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol'; 

contract NFT is ERC721 {
  address public owner;  
  uint public basePrice = 1000;
  uint public lastTokenId = 0;
  address tokenAddress;

  constructor(address _tokenAddress) ERC721('MyNFT', 'NFT') {
    tokenAddress = _tokenAddress;
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(owner == msg.sender, "You're are not the owner");
    _;
  }

  function mintNFT(uint _number) external {
      require(IERC20(tokenAddress).balanceOf(msg.sender) >= (_number * basePrice), "You don't have enough balance");
      IERC20(tokenAddress).transferFrom(msg.sender, address(this), (_number * basePrice));
      for (uint i = 0; i < _number; i++){
          _mint(msg.sender, lastTokenId);
          lastTokenId++;
      }
  }
}