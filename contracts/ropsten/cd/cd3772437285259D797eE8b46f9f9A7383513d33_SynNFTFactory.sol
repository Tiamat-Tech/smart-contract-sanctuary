// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Author: Francesco Sullo <[email protected]>
// Forked from EverDragons2(.com)'s code

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

interface ISynNFT {
  function safeMint(address to, uint256 quantity) external;

  function symbol() external returns (string memory);

  function balanceOf(address owner) external view returns (uint256);

  function nextTokenId() external view returns (uint256);
}

contract SynNFTFactory is Ownable {
  using ECDSA for bytes32;
  using SafeMath for uint256;

  event NFTSet(address nftAddress);
  event ValidatorSet(address validator);
  event TreasurySet(address treasury);

  uint256 public withdrawnAmount;
  uint256 public limit;

  address public validator;
  address public treasury;

  mapping(bytes32 => uint8) public usedCodes;

  // 1 word of storage in total
  struct NFTConf {
    ISynNFT nft;
    uint256 price;
    uint256 maxAllocation;
    uint256 remainingFreeTokens;
    bool paused;
  }

  mapping(address => NFTConf) public nftConf;

  function setValidatorAndTreasury(address validator_, address treasury_) external onlyOwner {
    setValidator(validator_);
    setTreasury(treasury_);
  }

  function setValidator(address validator_) public onlyOwner {
    require(validator_ != address(0), "validator cannot be 0x0");
    validator = validator_;
  }

  function setTreasury(address treasury_) public onlyOwner {
    require(treasury_ != address(0), "treasury cannot be 0x0");
    treasury = treasury_;
  }

  function getNftConf(address nftAddress) external view returns (NFTConf memory) {
    return nftConf[nftAddress];
  }

  // it implicitly starts the sale at the first call
  function openPauseSale(address nftAddress, bool paused) external {
    NFTConf memory conf = nftConf[nftAddress];
    conf.paused = paused;
    nftConf[nftAddress] = conf;
  }

  function init(address nftAddress, uint256 remainingFreeTokens) external onlyOwner {
    require(validator != address(0) && treasury != address(0), "validator and/or treasury not set, yet");
    ISynNFT synNFT = ISynNFT(nftAddress);
    nftConf[nftAddress] = NFTConf({
      nft: synNFT,
      price: 10**18, // < 10 ETH, to be changed
      maxAllocation: 5,
      paused: true,
      remainingFreeTokens: remainingFreeTokens
    });
    emit NFTSet(nftAddress);
  }

  function updatePriceAndMaxAllocation(
    address nftAddress,
    uint256 price,
    uint256 maxAllocation
  ) external onlyOwner {
    require(address(nftConf[nftAddress].nft) != address(0), "trying to modify a not existing conf");
    if (nftConf[nftAddress].price != price) {
      nftConf[nftAddress].price = price;
    }
    if (nftConf[nftAddress].maxAllocation != maxAllocation) {
      nftConf[nftAddress].maxAllocation = maxAllocation;
    }
  }

  function claimAFreeToken(
    address nftAddress,
    bytes32 authCode,
    bytes memory signature
  ) public {
    // parameters are validated during the off-chain validation
    require(usedCodes[authCode] == 0, "authCode already used");
    require(isSignedByValidator(encodeForSignature(_msgSender(), nftAddress, authCode), signature), "invalid signature");
    NFTConf memory conf = nftConf[nftAddress];
    require(conf.nft.balanceOf(_msgSender()) == 0, "only one token per wallet");
    require(conf.remainingFreeTokens >= 1, "no more free tokens available");
    conf.nft.safeMint(_msgSender(), 1);
    usedCodes[authCode] = 1;
    nftConf[nftAddress].remainingFreeTokens--;
  }

  function buyDiscountedTokens(
    address nftAddress,
    uint256 quantity,
    bytes32 authCode,
    uint256 discountedPrice,
    bytes memory signature
  ) external payable {
    // parameters are validated during the off-chain validation
    NFTConf memory conf = nftConf[nftAddress];
    require(!conf.paused, "sale is either not open or has been paused");
    require(usedCodes[authCode] == 0, "authCode already used");
    require(conf.nft.balanceOf(_msgSender()) + quantity <= conf.maxAllocation, "quantity exceeds max allocation");
    require(
      isSignedByValidator(encodeForSignature(_msgSender(), nftAddress, quantity, authCode, discountedPrice), signature),
      "invalid signature"
    );
    require(msg.value >= discountedPrice.mul(quantity), "insufficient payment");
    conf.nft.safeMint(_msgSender(), quantity);
    usedCodes[authCode] = 1;
  }

  function giveawayTokens(
    address nftAddress,
    address[] memory recipients,
    uint256[] memory quantities
  ) external onlyOwner {
    require(recipients.length == quantities.length, "inconsistent lengths");
    NFTConf memory conf = nftConf[nftAddress];
    for (uint256 i = 0; i < recipients.length; i++) {
      conf.nft.safeMint(recipients[i], quantities[i]);
    }
  }

  function buyTokens(address nftAddress, uint256 quantity) public payable {
    NFTConf memory conf = nftConf[nftAddress];
    require(!conf.paused, "sale is either not open or has been paused");
    require(conf.nft.balanceOf(_msgSender()) + quantity <= conf.maxAllocation, "quantity exceeds max allocation");
    require(msg.value >= conf.price.mul(quantity), "insufficient payment");
    conf.nft.safeMint(_msgSender(), quantity);
  }

  // cryptography

  function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool) {
    return validator == ECDSA.recover(_hash, _signature);
  }

  function encodeForSignature(
    address recipient,
    address nftAddress,
    bytes32 authCode
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          recipient,
          nftAddress,
          authCode
        )
      );
  }

  function encodeForSignature(
    address recipient,
    address nftAddress,
    uint256 quantity,
    bytes32 authCode,
    uint256 discountedPrice
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          recipient,
          nftAddress,
          quantity,
          authCode,
          discountedPrice
        )
      );
  }

  // withdraw

  function withdrawProceeds(uint256 amount) external {
    require(_msgSender() == treasury, "not the treasury");
    uint256 available = address(this).balance;
    if (amount == 0) {
      amount = available;
    }
    require(amount <= available, "Insufficient funds");
    (bool success, ) = _msgSender().call{value: amount}("");
    require(success);
  }
}