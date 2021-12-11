// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IDarenMedal.sol";
import "./DarenToken.sol";

contract DarenMedal is
  IDarenMedal,
  ERC721EnumerableUpgradeable,
  OwnableUpgradeable,
  PausableUpgradeable
{
  address darenToken;

  uint256 private primaryKey; // Order index
  mapping(uint256 => Order) public orders;

  function initialize() public initializer {
    __ERC721_init("Daren Test Medal Token", "DTM");
    __ERC721Enumerable_init();
    __Ownable_init();
    // Reserve first 30 ponies to contract owner
    // for (uint256 i = 0; i < 30; i++) {
    //   super._mint(msg.sender, totalSupply());
    // }
  }

  function zeng(address account, uint256 tokenId) external onlyOwner {
    _mint(account, tokenId);
  }

  function shao(uint256 tokenId) external onlyOwner {
    _burn(tokenId);
  }

  function hasTokenIdInRange(
    address owner,
    uint256 from,
    uint256 to
  ) external view returns (bool) {
    require(from <= to, "Range to should greater than range from.");

    for (uint256 i = 0; i < balanceOf(owner); i++) {
      uint256 tokenId = tokenOfOwnerByIndex(owner, i);
      if (tokenId >= from && tokenId <= to) {
        return true;
      }
    }
    return false;
  }

  function hasTokenIdInArray(address owner, uint256[] memory list)
    external
    view
    returns (bool)
  {
    require(list.length > 0, "List should not empty.");
    for (uint256 i = 0; i < balanceOf(owner); i++) {
      uint256 tokenId = tokenOfOwnerByIndex(owner, i);

      for (uint256 j = 0; j < list.length; j++) {
        if (tokenId == list[j]) {
          return true;
        }
      }
    }
    return false;
  }

  function getTokensInRange(
    address _owner,
    uint256 _from,
    uint256 _to
  ) external view returns (uint256[] memory) {
    uint256 balance = balanceOf(_owner);
    if (balance <= 0) {
      return new uint256[](0);
    }

    uint256 count;
    for (uint256 i = 0; i < balance; i++) {
      uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
      if (tokenId >= _from && tokenId <= _to) {
        count++;
      }
    }
    uint256[] memory ids = new uint256[](count);
    uint256 index;
    for (uint256 i = 0; i < balance; i++) {
      uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
      if (tokenId >= _from && tokenId <= _to) {
        ids[index++] = tokenId;
      }
    }

    return ids;
  }

  function setDarenTokenAddress(address _darenTokenAddress) external onlyOwner {
    darenToken = _darenTokenAddress;
  }

  // Override =================================

  function transfer(
    address from,
    address to,
    uint256 tokenId
  ) external {
    require(orders[tokenId].tokenId == 0, "token in sell");

    _transfer(from, to, tokenId);
  }

  // Market ===================================

  function createOrder(uint256 _tokenId, uint256 _price) public {
    address sender = _msgSender();

    require(ownerOf(_tokenId) == sender, "Only the owner can create order.");
    require(_price > 0, "Price should be greater than 0");

    primaryKey += 1;
    orders[_tokenId] = Order({
      pk: primaryKey,
      tokenId: _tokenId,
      price: _price,
      seller: sender,
      createdAt: block.timestamp
    });

    emit OrderCreated({ tokenId: _tokenId, price: _price, seller: sender });
  }

  function orderInSell(uint256 _tokenId) external view returns (bool) {
    Order memory order = orders[_tokenId];

    return order.pk > 0;
  }

  function cancelOrder(uint256 _tokenId) public {
    address sender = _msgSender();
    Order memory order = orders[_tokenId];

    require(order.pk != 0, "Order not published");
    require(order.seller == sender || sender == owner(), "Unauthorized user");

    delete orders[_tokenId];

    emit OrderCanceled(_tokenId);
  }

  function executeOrder(uint256 _tokenId) public {
    address sender = _msgSender();
    Order memory goods = orders[_tokenId];
    require(goods.seller != sender, "Seller can't execute the order");
    require(darenToken != address(0), "Daren Token didn't set");
    DarenToken dt = DarenToken(darenToken);
    require(
      dt.allowance(sender, address(this)) > goods.price,
      "needs more allowance"
    );
    require(goods.seller == ownerOf(_tokenId), "Seller is not the owner");

    dt.transferFrom(sender, goods.seller, goods.price);
    _transfer(goods.seller, sender, _tokenId);

    delete orders[_tokenId];

    emit OrderExecuted({
      tokenId: _tokenId,
      price: goods.price,
      buyer: sender,
      seller: goods.seller
    });
  }
}