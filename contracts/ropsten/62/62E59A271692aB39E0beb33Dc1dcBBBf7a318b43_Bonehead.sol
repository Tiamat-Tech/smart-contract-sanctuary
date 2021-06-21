// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Bonehead is Ownable, ERC721 {
  using SafeMath for uint256;

  // teamTokens represents amount of minted tokens for team, max value must be 500
  uint256 public teamTokens;
  // userTokens represents amount of minted tokens for buyer, max value must be 9500
  uint256 public userTokens;
  // active displays the status of token purchase availability
  bool public active = false;
  // limitPerAddress displays max amount tokens for one address
  uint256 public constant limitPerAddress = 30;
  // cost displays price on token minting
  uint256 public constant cost = 0.2 ether;

  constructor(string memory _name, string memory _symbol) public ERC721(_name, _symbol) { }
  
  // Transfer funds
  function withdraw() public onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  // Set base URI
  function setBaseURI(string memory _baseURI) public onlyOwner {
    ERC721._setBaseURI(_baseURI);
  }

  // Set token URI
  function setTokenURI(uint256[] memory _tokenIDs, string[] memory _tokenURIs) public onlyOwner {
    require(_tokenIDs.length == _tokenURIs.length, "InvalidLength");
    for(uint256 i = 0; i < _tokenIDs.length; ++i) {
      ERC721._setTokenURI(_tokenIDs[i], _tokenURIs[i]);
    }
  }

  // Reserve tokens
  function reserve(uint256 _amount) public onlyOwner {
    require(_amount != 0, "InvalidAmount");

    uint256 _teamTokens = teamTokens;
    uint256 _tokenID = _teamTokens.add(userTokens);
    
    for (uint256 i = 0; i < _amount; ++i) {
      _safeMint(msg.sender, _tokenID + i);
    }

    _teamTokens = _teamTokens.add(_amount);
    teamTokens = _teamTokens;
    require(_teamTokens <= 500, "TeamTokensExceeded");
  }

  // Toggles minting
  function toggleState() public onlyOwner {
    active = !active;
  }

  // Create token with checks
  function mint(uint256 _amount) public payable {
    require(active, "NotActive");
    require(_amount != 0, "InvalidAmount");
    require (_amount.add(ERC721.balanceOf(msg.sender)) <= limitPerAddress, "ExceededLimitPerAddress");
    require (cost.mul(_amount) == msg.value, "InvalidMsgValue");

    uint256 _userTokens = userTokens;
    uint256 _tokenID = _userTokens.add(teamTokens);

    for (uint256 i = 0; i < _amount; ++i) {
      _safeMint(msg.sender, _tokenID + i);
    }

    _userTokens = _userTokens.add(_amount);
    userTokens = _userTokens;
    require(_userTokens <= 9500, "UserTokensExceeded");
  }
}