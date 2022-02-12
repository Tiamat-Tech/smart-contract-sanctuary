// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

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

  constructor(address verifier) ERC721A("CerealClub", "CEREAL") {
    _verifier = verifier;
  }

  // AUCTION

  function startAuction() external onlyOwner {
    _auctionStart = block.timestamp;
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
      return Math.max(
        AUCTION_MIN_PRICE,
        AUCTION_START_PRICE - (steps * AUCTION_STEP_PRICE)
      );
    }
  }

  function auctionMint() external payable nonReentrant onlyEOA {
    require(isAuctionActive(), "auction not active");
    require(totalSupply() < MAX_SUPPLY, "supply exhausted");
    require(balanceOf(msg.sender) < 1, "exceeds mint limit");

    _safeMint(msg.sender, 1);

    // Refund overpayment
    uint256 price = getAuctionPrice();
    require(msg.value >= price, "insufficient payment");
    if (msg.value > price) {
      payable(msg.sender).transfer(msg.value - price);
    }
  }

  // PRESALE WHITELIST

  function startPresale() external onlyOwner {
    _auctionStart = FAR_FUTURE;
    _presaleStart = block.timestamp;
    _salePrice = getAuctionPrice() / 2;
  }

  function isPresaleActive() public view returns (bool) {
    return block.timestamp > _presaleStart;
  }

  function getSalePrice() public view returns (uint256) {
    return _salePrice;
  }

  function presaleMint(bytes calldata sig) external payable nonReentrant onlyEOA {
    require(isPresaleActive(), "presale not active");
    require(isWhitelisted(msg.sender, sig), "unauthorized");
    require(totalSupply() < MAX_SUPPLY, "supply exhausted");
    require(balanceOf(msg.sender) < 1, "exceeds limit");
    require(getSalePrice() == msg.value, "incorrect payment");

    _safeMint(msg.sender, 1);
  }

  function isWhitelisted(address account, bytes calldata sig) internal view returns (bool) {
    return ECDSA.recover(keccak256(abi.encodePacked(account)).toEthSignedMessageHash(), sig) == _verifier;
  }

  // PUBLIC SALE

  function startPublicSale() external onlyOwner {
    _auctionStart = FAR_FUTURE;
    _presaleStart = FAR_FUTURE;
    _publicSaleStart = block.timestamp;
  }

  function isPublicSaleActive() public view returns (bool) {
    return block.timestamp > _publicSaleStart;
  }

  function publicSaleMint(uint256 amount) external payable nonReentrant onlyEOA {
    require(isPublicSaleActive(), "public sale not active");
    require(totalSupply() + amount <= MAX_SUPPLY, "supply exhausted");
    require(balanceOf(msg.sender) < 1, "exceeds limit");
    require(getSalePrice() == msg.value, "incorrect payment");

    _safeMint(msg.sender, amount);
  }

  // METADATA

  string private _baseTokenURI;

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  // OWNERS + HELPERS

  modifier onlyEOA() {
    require(tx.origin == msg.sender, "eos only");
    _;
  }

  function pauseSale() external onlyOwner {
    _auctionStart = FAR_FUTURE;
    _presaleStart = FAR_FUTURE;
    _publicSaleStart = FAR_FUTURE;
  }

  function teamMint(uint256 quantity) external onlyOwner {
    require(totalSupply() + quantity <= MAX_SUPPLY, "supply exhausted");

    _safeMint(msg.sender, quantity);
  }

  function withdraw(address recipient) external onlyOwner {
    payable(recipient).transfer(address(this).balance);
  }
}