pragma solidity ^0.8.4;

import './ERC721A.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

error AmountExceedsSupply();
error IncorrectPayment();
error AmountExceedsTransactionLimit();

contract ProjectN is ERC721A, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  
  uint256 public constant MAX_SUPPLY = 10;
  uint256 public constant MAX_MINTS_PER_TX = 2;
  uint256 private _salePrice = 0.01 ether;
  string private _baseTokenURI;

  constructor() ERC721A("ProjectN", "PROJECTN") {}

  function publicMint(uint256 quantity) external payable {
    // if (!isPublicSaleActive())                  revert SaleNotStarted();
    if (totalSupply() + quantity > MAX_SUPPLY)  revert AmountExceedsSupply();
    if (getSalePrice() * quantity != msg.value) revert IncorrectPayment();
    if (quantity > MAX_MINTS_PER_TX)            revert AmountExceedsTransactionLimit();
    _safeMint(msg.sender, quantity);
  }

  function getSalePrice() public view returns (uint256) {
    return _salePrice;
  }
}