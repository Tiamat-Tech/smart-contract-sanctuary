// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TemplateERC721 is ERC721URIStorage, Ownable {
  uint256 public tokenCounter;
  string public internalTokenURI;
  IERC20 public token;
  uint256 public minTokenRequirement;
  mapping(address => bool) public minted;

  constructor(string memory _tokenURI, address _tokenGateAddress, uint256 _minTokenRequirement)
    ERC721("TestToken", "TT01")
  {
    tokenCounter = 0;
    internalTokenURI = _tokenURI;
    token = IERC20(_tokenGateAddress);
    minTokenRequirement = _minTokenRequirement;
  }

  function mintCollectible() public {
    require(token.balanceOf(msg.sender) > minTokenRequirement, "Owner doesn't have enough of the token");
    require(minted[msg.sender] == false, "NFT already minted");
    minted[msg.sender] = true;

    uint256 newTokenId = tokenCounter;
    tokenCounter++;
    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, internalTokenURI);
  }

  function canMint() public view returns (bool) {
    return token.balanceOf(msg.sender) > minTokenRequirement;
  }
}