// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

error SaleNotStarted();
error InsufficientPayment();
error IncorrectPayment();
error AccountNotWhitelisted();
error AmountExceedsMaxSupply();
error AmountExceedsWhitelistLimit();
error AmountExceedsTransactionLimit();
error OnlyExternallyOwnedAccountsAllowed();

contract CerealClub is ERC721A, Ownable, ReentrancyGuard {
  using ECDSA for bytes32;

  uint256 public constant MAX_SUPPLY = 10000;

  uint256 private constant AUCTION_START_PRICE = 0.5 ether;
  uint256 private constant AUCTION_STEP_PRICE = 0.05 ether;
  uint256 private constant AUCTION_STEP_SECONDS = 10 minutes;
  uint256 private constant AUCTION_MIN_PRICE = 0.1 ether;
  uint256 private constant FAR_FUTURE = 0xFFFFFFFFF;
  uint256 private constant MAX_MINTS_PER_TX = 5;

  uint256 private _auctionStart = FAR_FUTURE;
  uint256 private _presaleStart = FAR_FUTURE;
  uint256 private _publicSaleStart = FAR_FUTURE;
  uint256 private _salePrice = 0.25 ether;

  address private _verifier;
  string private _baseTokenURI;
  mapping(address => bool) private _mintedWhitelist;

  event AuctionStart(uint256 price);
  event PresaleStart(uint256 price, uint256 supplyRemaining);
  event PublicSaleStart(uint256 price, uint256 supplyRemaining);
  event SalePaused();

  constructor(address verifier) ERC721A("CerealClub", "CEREAL") {
    _verifier = verifier;
  }

  // AUCTION

  function startAuction() external onlyOwner {
    _auctionStart = block.timestamp;

    emit AuctionStart(getAuctionPrice());
  }

  function isAuctionActive() public view returns (bool) {
    return block.timestamp > _auctionStart;
  }

  function getAuctionPrice() public view returns (uint256) {
    unchecked {
      uint256 steps = (block.timestamp - _auctionStart) / AUCTION_STEP_SECONDS;
      if (steps > FAR_FUTURE) { // overflow if not started
        return AUCTION_START_PRICE;
      }
      uint256 discount = steps * AUCTION_STEP_PRICE;
      if (discount > AUCTION_START_PRICE) {
        return AUCTION_MIN_PRICE;
      }
      return AUCTION_START_PRICE - discount;
    }
  }

  function auctionMint(uint256 amount) external payable nonReentrant onlyEOA {
    if (!isAuctionActive())                  revert SaleNotStarted();
    if (totalSupply() + amount > MAX_SUPPLY) revert AmountExceedsMaxSupply();
    if (amount > 5)                          revert AmountExceedsTransactionLimit();

    _safeMint(msg.sender, amount);

    // Refund overpayment
    uint256 price = getAuctionPrice() * amount;
    if (msg.value < price) revert InsufficientPayment();
    if (msg.value > price) {
      payable(msg.sender).transfer(msg.value - price);
    }
  }

  // PRESALE WHITELIST

  function startPresale(uint256 price) external onlyOwner {
    _auctionStart = FAR_FUTURE;
    _presaleStart = block.timestamp;
    _salePrice = price;

    emit PresaleStart(price, MAX_SUPPLY - totalSupply());
  }

  function isPresaleActive() public view returns (bool) {
    return block.timestamp > _presaleStart;
  }

  function getSalePrice() public view returns (uint256) {
    return _salePrice;
  }

  function presaleMint(bytes calldata sig) external payable nonReentrant onlyEOA {
    if (!isPresaleActive())              revert SaleNotStarted();
    if (!isWhitelisted(msg.sender, sig)) revert AccountNotWhitelisted();
    if (hasMintedPresale(msg.sender))    revert AmountExceedsWhitelistLimit();
    if (totalSupply() >= MAX_SUPPLY)     revert AmountExceedsMaxSupply();
    if (getSalePrice() != msg.value)     revert IncorrectPayment();

    _mintedWhitelist[msg.sender] = true;
    _safeMint(msg.sender, 1);
  }

  function hasMintedPresale(address account) public view returns (bool) {
    return _mintedWhitelist[account];
  }

  function isWhitelisted(address account, bytes calldata sig) internal view returns (bool) {
    return ECDSA.recover(keccak256(abi.encodePacked(account)).toEthSignedMessageHash(), sig) == _verifier;
  }

  // PUBLIC SALE

  function startPublicSale() external onlyOwner {
    _auctionStart = FAR_FUTURE;
    _presaleStart = FAR_FUTURE;
    _publicSaleStart = block.timestamp;

    emit PublicSaleStart(getSalePrice(), MAX_SUPPLY - totalSupply());
  }

  function isPublicSaleActive() public view returns (bool) {
    return block.timestamp > _publicSaleStart;
  }

  function publicSaleMint(uint256 amount) external payable nonReentrant onlyEOA {
    if (!isPublicSaleActive())                revert SaleNotStarted();
    if (totalSupply() + amount > MAX_SUPPLY)  revert AmountExceedsMaxSupply();
    if (getSalePrice() * amount != msg.value) revert IncorrectPayment();
    if (amount > 5)                           revert AmountExceedsTransactionLimit();

    _safeMint(msg.sender, amount);
  }

  // METADATA

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  // OWNERS + HELPERS

  modifier onlyEOA() {
    if (tx.origin != msg.sender) revert OnlyExternallyOwnedAccountsAllowed();
    _;
  }

  function setSalePrice(uint256 price) external onlyOwner {
    _salePrice = price;
  }

  function pauseSale() external onlyOwner {
    _auctionStart = FAR_FUTURE;
    _presaleStart = FAR_FUTURE;
    _publicSaleStart = FAR_FUTURE;

    emit SalePaused();
  }

  function teamMint(uint256 amount) external onlyOwner {
    if (totalSupply() + amount > MAX_SUPPLY) revert AmountExceedsMaxSupply();

    _safeMint(msg.sender, amount);
  }

  function withdraw(address recipient) external onlyOwner {
    payable(recipient).transfer(address(this).balance);
  }
}