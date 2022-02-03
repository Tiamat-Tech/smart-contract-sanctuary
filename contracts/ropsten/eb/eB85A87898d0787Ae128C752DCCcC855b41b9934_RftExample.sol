// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Trustable.sol";
import "./NftExample.sol";

contract RftExample is ERC20, ReentrancyGuard, Trustable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct User {
    uint256 bonus;
  }

  NftExample public nft;
  IERC20 public usdc;
  address public admin;
  uint256 shareSupply;
  uint256 sharePrice;
  mapping(address => User) public users;

  constructor(
    string memory _name,
    string memory _symbol,
    NftExample _nft,
    address _usdcAddress,
    uint256 _shareSupply,
    uint256 _sharePrice
  ) ERC20(_name, _symbol) {
    nft = _nft;
    usdc = IERC20(_usdcAddress);
    shareSupply = _shareSupply;
    sharePrice = _sharePrice;

    admin = msg.sender;
  }

  function buy(uint256 shareAmount) external nonReentrant {
    require(totalSupply() + shareAmount <= shareSupply, "not enough shares left");

    uint usdcAmount = shareAmount * sharePrice;
    usdc.transferFrom(address(msg.sender), address(this), usdcAmount);
    _mint(msg.sender, shareAmount);
  }

  function sell(uint256 shareAmount) external nonReentrant {
    uint balance = usdc.balanceOf(address(this));
    uint usdcAmount = shareAmount * sharePrice;

    User storage user = users[msg.sender];

    if (user.bonus > 0) {
      usdcAmount = usdcAmount.add(user.bonus * sharePrice);
    }

    require(balance >= usdcAmount, "not enough balance");

    usdc.transfer(msg.sender, usdcAmount);
    _burn(msg.sender, shareAmount);
  }

  function depositNFT(uint256 nftId) external {
    nft.transferFrom(address(msg.sender), address(this), nftId);

    User storage user = users[msg.sender];

    user.bonus += nft.getTypeByTokenId(nftId).bonus;
  }

  function withdrawNFT(uint256 nftId) public {
    nft.transferFrom(address(this), address(msg.sender), nftId);

    User storage user = users[msg.sender];

    user.bonus -= nft.getTypeByTokenId(nftId).bonus;
  }
}