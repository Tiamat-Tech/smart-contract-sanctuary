//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./AniftyERC1155.sol";

contract AniftyCollection is Ownable, Pausable, ERC1155Holder {
  using SafeMath for uint256;

  struct CollectionInfo {
    uint256 tokenId;
    uint256 price;
    address ERC20Token;
  }

  uint256 public roundId;
  // List of ERC20 tokens that are currently being used as a payment option for a collection
  address[] public paymentERC20Tokens;
  // Mapping to check if ERC20 exists in the list
  mapping(address => bool) public existingERC20Token;
  // Mapping of round to collections
  mapping(uint256 => CollectionInfo[]) public roundCollection;
  // Address of Anifty's ERC1155 contract
  AniftyERC1155 public aniftyERC1155;

  constructor(address _aniftyERC1155) public {
      aniftyERC1155 = AniftyERC1155(_aniftyERC1155);
  }

  /********************** BUY ********************************/

  function buyCollectable(uint256 _collectableIndex) payable external whenNotPaused {
    CollectionInfo memory collectable = roundCollection[roundId][_collectableIndex];
    require(aniftyERC1155.balanceOf(address(this), collectable.tokenId) > 0, 'AniftyCollection: Collectable sold out');
    // Empty address indicates the collectable accepts ETH as payment
    if (collectable.ERC20Token == address(0)) {
      require(msg.value >= collectable.price, 'AniftyCollection: Insufficient fund to buy collectable');
    } else {
      IERC20(collectable.ERC20Token).transferFrom(msg.sender, address(this), collectable.price);
    }
    aniftyERC1155.safeTransferFrom(address(this), msg.sender, collectable.tokenId, 1, "");
  }

  /********************** OWNER ********************************/

  function addToCollection(
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    address[] memory ERC20Tokens,
    uint256[] memory prices) external onlyOwner {
      require(amounts.length == ERC20Tokens.length && amounts.length == prices.length, "AniftyCollection: Incorrect parameter length");
      aniftyERC1155.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");
      roundId = roundId.add(1);
      for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        address ERC20Token = ERC20Tokens[i];
        uint256 price = prices[i];
        roundCollection[roundId].push(CollectionInfo(tokenId, price, ERC20Token));
        if (!existingERC20Token[ERC20Token] && ERC20Token != address(0)) {
          paymentERC20Tokens.push(ERC20Token);
        }
      }
  }

  function addToRound(
    uint256 addRoundId,
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    address[] memory ERC20Tokens,
    uint256[] memory prices) external onlyOwner {
      require(amounts.length == ERC20Tokens.length && amounts.length == prices.length, "AniftyCollection: Incorrect parameter length");
      aniftyERC1155.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, "");
      for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        address ERC20Token = ERC20Tokens[i];
        uint256 price = prices[i];
        roundCollection[addRoundId].push(CollectionInfo(tokenId, price, ERC20Token));
        if (!existingERC20Token[ERC20Token] && ERC20Token != address(0)) {
          paymentERC20Tokens.push(ERC20Token);
        }
      }
    }

  function withdrawETH() public onlyOwner {
    msg.sender.transfer(address(this).balance);
  }

  function withdrawERC20(address ERC20Token) public onlyOwner {
    IERC20 withdrawToken = IERC20(ERC20Token);
    withdrawToken.transfer(msg.sender, withdrawToken.balanceOf(address(this)));
  }

  function withdrawAllERC20() public onlyOwner {
    for (uint256 i = 0; i < paymentERC20Tokens.length; i++) {
      withdrawERC20(paymentERC20Tokens[i]);
    }
  }

  function withdrawAllTokens() external onlyOwner {
    withdrawETH();
    withdrawAllERC20();
  }

  function withdrawERC1155(uint256 tokenId, uint256 amount) public onlyOwner {
    aniftyERC1155.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
  }

  function withdrawAllERC1155(uint256 withdrawRoundId) external onlyOwner {
    for (uint256 i = 0; i < roundCollection[withdrawRoundId].length; i++) {
      CollectionInfo memory collectable = roundCollection[withdrawRoundId][i];
      uint256 ERC1155Balance = aniftyERC1155.balanceOf(address(this), collectable.tokenId);
      if (ERC1155Balance > 0) {
        withdrawERC1155(collectable.tokenId, ERC1155Balance);
      }
    }
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }
}