// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./Trustable.sol";
import "./NftExample.sol";

contract RftExample is ERC20, ERC721Holder, ReentrancyGuard, Trustable {
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

    admin = _msgSender();
  }

  function buy(uint256 shareAmount) external nonReentrant {
    require(totalSupply() + shareAmount <= shareSupply, "not enough shares left");

    uint usdcAmount = shareAmount * sharePrice;
    usdc.transferFrom(address(_msgSender()), address(this), usdcAmount);
    _mint(_msgSender(), shareAmount);
  }

  function sell(uint256 shareAmount) external nonReentrant {
    uint balance = usdc.balanceOf(address(this));
    uint usdcAmount = shareAmount * sharePrice;

    User storage user = users[_msgSender()];

    if (user.bonus > 0) {
      usdcAmount = usdcAmount.add(user.bonus * sharePrice);
    }

    require(balance >= usdcAmount, "not enough balance");

    usdc.transfer(_msgSender(), usdcAmount);
    _burn(_msgSender(), shareAmount);
  }

  function depositNFT(uint256 nftId) external {
    nft.safeTransferFrom(address(_msgSender()), address(this), nftId);

    User storage user = users[_msgSender()];

    user.bonus += nft.getTypeByTokenId(nftId).bonus;
  }

  function withdrawNFT(uint256 nftId) public {
    nft.safeTransferFrom(address(this), address(_msgSender()), nftId);

    User storage user = users[_msgSender()];

    user.bonus -= nft.getTypeByTokenId(nftId).bonus;
  }
}