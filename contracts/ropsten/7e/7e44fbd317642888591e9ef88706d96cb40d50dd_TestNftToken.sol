// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./erc721a/ERC721A.sol";

contract TestNftToken is Ownable, ERC721A {
  constructor() ERC721A("TestNft", "TNFT") {}

   // // metadata URI
  string private _baseTokenURI;

  uint256 private constant _collectionSize = 8893;

  function isMinted() public view virtual returns (bool) {
      return _collectionSize == (_currentIndex + 1);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  receive() external payable {
        
  }

  function withdrawMoney() external onlyOwner {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  function mint(uint256 quantity) external payable onlyOwner {
    require(
      !isMinted(),
      "collection was minted."
    );
    uint256 maxQuantity = _collectionSize - (_currentIndex + 1);
    if (quantity > maxQuantity)
      quantity = maxQuantity;
    _safeMint(msg.sender, quantity);
  }
}