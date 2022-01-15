pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace2 is Ownable {
  using SafeMath for uint256;

  uint256 public taxDaoPercent = 2;

  mapping(address => mapping(uint256 => uint256)) public itemIsSelling;

  event itemAdded(
    address tokenAddress,
    address userAddress,
    uint256 tokenId,
    uint256 price
  );
  event itemSold(address tokenAddress, address userAddress, uint256 tokenId);
  event itemDelete(address tokenAddress, address userAddress, uint256 tokenId);

  modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
    IERC721 tokenContract = IERC721(tokenAddress);
    require(tokenContract.ownerOf(tokenId) == msg.sender, "not item owner");
    _;
  }

  modifier HasTransferApproval(address tokenAddress) {
    IERC721 tokenContract = IERC721(tokenAddress);
    require(
      tokenContract.isApprovedForAll(msg.sender, address(this)),
      "is not approved"
    );
    _;
  }

  modifier IsForSale(address tokenAddress, uint256 tokenId) {
    require(itemIsSelling[tokenAddress][tokenId] > 0, "Item is not for sale");
    _;
  }

  function setTaxDaoPercent(uint256 percent) external onlyOwner {
    taxDaoPercent = percent;
  }

  function tokenOwner(address tokenAddress, uint256 tokenId)
    external
    view
    returns (address)
  {
    IERC721 tokenContract = IERC721(tokenAddress);
    address owner = tokenContract.ownerOf(tokenId);

    return owner;
  }

  function addItemToMarket(
    address tokenAddress,
    uint256 tokenId,
    uint256 price
  )
    external
    OnlyItemOwner(tokenAddress, tokenId)
    HasTransferApproval(tokenAddress)
  {
    require(
      itemIsSelling[tokenAddress][tokenId] == 0,
      "Item is already up for sale!"
    );
    itemIsSelling[tokenAddress][tokenId] = price;

    emit itemAdded(tokenAddress, msg.sender, tokenId, price);
  }

  function delItemFromMarket(address tokenAddress, uint256 tokenId)
    external
    OnlyItemOwner(tokenAddress, tokenId)
    HasTransferApproval(tokenAddress)
    IsForSale(tokenAddress, tokenId)
  {
    itemIsSelling[tokenAddress][tokenId] = 0;

    emit itemDelete(tokenAddress, msg.sender, tokenId);
  }

  function buyItem(address tokenAddress, uint256 tokenId)
    external
    payable
    IsForSale(tokenAddress, tokenId)
  {
    require(
      msg.value >= itemIsSelling[tokenAddress][tokenId],
      "Not enough funds sent"
    );

    itemIsSelling[tokenAddress][tokenId] = 0;
    IERC721 tokenContract = IERC721(tokenAddress);
    IERC721(tokenAddress).safeTransferFrom(
      tokenContract.ownerOf(tokenId),
      msg.sender,
      tokenId
    );

    uint256 tax = msg.value.div(100).mul(taxDaoPercent);

    payable(tokenContract.ownerOf(tokenId)).transfer(msg.value.sub(tax));
    // delete activeItems[itemsForSale[id].tokenAddress][itemsForSale[id].tokenId];

    emit itemSold(tokenAddress, msg.sender, tokenId);
  }
}