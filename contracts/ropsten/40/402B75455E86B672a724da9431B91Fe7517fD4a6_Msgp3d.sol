// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Msgp3d is Ownable, ERC721A, ReentrancyGuard {

  mapping(address => uint256) public allowlist;

  constructor(
    uint256 maxBatchSize_,
    uint256 collectionSize_
  ) ERC721A("MoonshotGarageProject", "MSGP", collectionSize_) {
    
  }

  modifier callerIsUser() {
    require(tx.origin == msg.sender, "The caller is another contract");
    _;
  }

  function auctionMint(uint256 quantity) external payable callerIsUser {
    // uint256 _saleStartTime = uint256(saleConfig.auctionSaleStartTime);
    // require(
    //   _saleStartTime != 0 && block.timestamp >= _saleStartTime,
    //   "sale has not started yet"
    // );
    // require(
    //   totalSupply() + quantity <= amountForAuctionAndDev,
    //   "not enough remaining reserved for auction to support desired mint amount"
    // );
    // require(
    //   numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint,
    //   "can not mint this many"
    // );
    // uint256 totalCost = getAuctionPrice(_saleStartTime) * quantity;
    _safeMint(msg.sender, quantity);
    // refundIfOver(totalCost);
  }

  function bulkMint(address[] memory who) public onlyOwner {
      for (uint256 i = 0; i < who.length; i++) _safeMint(who[i], 1);
  }
  function bulkMintMap(address[] memory who, uint256[] memory quantityList) public onlyOwner {
      for (uint256 i = 0; i < who.length; i++) _safeMint(who[i], quantityList[i]);
  }


  // // metadata URI
  string private _baseTokenURI;

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function withdrawMoney() external onlyOwner nonReentrant {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  function setOwnersExplicit(uint256 quantity) external onlyOwner nonReentrant {
    _setOwnersExplicit(quantity);
  }

  function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
  }

  function getOwnershipData(uint256 tokenId)
    external
    view
    returns (TokenOwnership memory)
  {
    return ownershipOf(tokenId);
  }
}