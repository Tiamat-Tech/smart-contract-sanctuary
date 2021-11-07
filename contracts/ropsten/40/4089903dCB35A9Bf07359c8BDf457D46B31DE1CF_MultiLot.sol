// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./IPriceFeed.sol";
import "./ILot.sol";

contract MultiLot is Ownable, ILot {
  address public priceFeed;

  address public collateralToken;

  uint256 public feePercentage;

  uint256 public ratioPrecision = 100000;

  uint256 public totalFee;

  struct Lot {
    string tokenA;
    string tokenB;
    uint256 startEpoch;
    uint256 duration;
    mapping(address => uint256) userDepositPoolA;
    mapping(address => uint256) userDepositPoolB;
    // store total deposit size to avoid iterating over userDepositPool mapping
    uint256 totalDepositPoolA;
    uint256 totalDepositPoolB;
    // startLot should only be started once
    bool started;
    uint256 startSize;
    uint256 startPriceTokenA;
    uint256 startPriceTokenB;
    // refunds should only be processed once
    mapping(address => bool) refunded;
    uint256 refundRatioPoolA;
    uint256 refundRatioPoolB;
    // resolveLot should only be called once
    bool resolved;
    // claims should only be processed once
    mapping(address => bool) claimed;
    uint256 totalClaimPoolA;
    uint256 totalClaimPoolB;
  }

  // lotId -> lot
  mapping(uint256 => Lot) private lots;

  uint256 public lastLotId;

  event LotCreated(
    uint256 lotId,
    string tokenA,
    string tokenB,
    address userA,
    uint256 size,
    uint256 startEpoch,
    uint256 duration
  );

  event LotJoined(uint256 lotId, string token, address user, uint256 size);

  event LotStarted(
    uint256 lotId,
    uint256 size,
    uint256 refundRatioPoolA,
    uint256 refundRatioPoolB,
    uint256 startPriceTokenA,
    uint256 startPriceTokenB
  );

  event LotResolved(
    uint256 lotId,
    string winningToken,
    uint256 resolvePriceTokenA,
    uint256 resolvePriceTokenB
  );

  event FeeCollected(uint256 lotId, uint256 amount);

  event Xfer(address user, uint256 value, int256 direction);

  constructor(
    address _priceFeed,
    address _collateralToken,
    uint256 _feePercentage
  ) {
    priceFeed = _priceFeed;
    collateralToken = _collateralToken;
    feePercentage = _feePercentage;
  }

  function depositCollateral(uint256 _amount)
    internal
    returns (bool isSuccessful)
  {
    isSuccessful = IERC20(collateralToken).transferFrom(
      msg.sender,
      address(this),
      _amount
    );
    require(isSuccessful, "transfer failed");
  }

  function createLot(
    string calldata _tokenA,
    string calldata _tokenB,
    uint256 _size,
    uint256 _startEpoch,
    uint256 _duration
  ) external {
    require(
      keccak256(bytes(_tokenA)) != keccak256(bytes(_tokenB)),
      "identical token addresses"
    );
    require(depositCollateral(_size), "insufficient collateral");

    Lot storage lot = lots[++lastLotId];
    lot.tokenA = _tokenA;
    lot.tokenB = _tokenB;
    lot.userDepositPoolA[msg.sender] += _size;
    lot.totalDepositPoolA += _size;
    lot.startEpoch = _startEpoch;
    lot.duration = _duration;

    emit LotCreated(
      lastLotId,
      lot.tokenA,
      lot.tokenB,
      msg.sender,
      _size,
      lot.startEpoch,
      lot.duration
    );
  }

  function joinLot(
    uint256 _lotId,
    string calldata _token,
    uint256 _size
  ) external {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(block.timestamp < lot.startEpoch, "too late");
    require(
      compareStrings(_token, lot.tokenA) || compareStrings(_token, lot.tokenB),
      "invalid token id for lot"
    );
    require(depositCollateral(_size), "insufficient collateral");

    if (compareStrings(_token, lot.tokenA)) {
      require(
        lot.userDepositPoolB[msg.sender] == 0,
        "cannot join on both sides"
      );
      lot.userDepositPoolA[msg.sender] += _size;
      lot.totalDepositPoolA += _size;
    } else {
      require(
        lot.userDepositPoolA[msg.sender] == 0,
        "cannot join on both sides"
      );
      lot.userDepositPoolB[msg.sender] += _size;
      lot.totalDepositPoolB += _size;
    }

    emit LotJoined(_lotId, _token, msg.sender, _size);
  }

  function startLot(uint256 _lotId) external {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(block.timestamp >= lot.startEpoch, "too early");
    require(!lot.started, "lot already started");

    lot.startSize = min(lot.totalDepositPoolA, lot.totalDepositPoolB);

    if (lot.startSize == lot.totalDepositPoolA) {
      lot.refundRatioPoolB =
        (ratioPrecision * (lot.totalDepositPoolB - lot.startSize)) /
        lot.totalDepositPoolB;
    } else {
      lot.refundRatioPoolA =
        (ratioPrecision * (lot.totalDepositPoolA - lot.startSize)) /
        lot.totalDepositPoolA;
    }

    lot.startPriceTokenA = uint256(IPriceFeed(priceFeed).getPrice(lot.tokenA));
    lot.startPriceTokenB = uint256(IPriceFeed(priceFeed).getPrice(lot.tokenB));

    lot.started = true;
    emit LotStarted(
      _lotId,
      lot.startSize,
      lot.refundRatioPoolA,
      lot.refundRatioPoolB,
      lot.startPriceTokenA,
      lot.startPriceTokenB
    );
  }

  function withdrawRefund(uint256 _lotId, string calldata _token) external {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(!lot.refunded[msg.sender], "already refunded");
    require(
      compareStrings(_token, lot.tokenA) || compareStrings(_token, lot.tokenB),
      "invalid token id for lot"
    );
    require(lot.started, "too early");

    uint256 userRefund;

    if (compareStrings(_token, lot.tokenA)) {
      uint256 userDeposit = lot.userDepositPoolA[msg.sender];
      userRefund = (userDeposit * lot.refundRatioPoolA) / ratioPrecision;
    } else {
      uint256 userDeposit = lot.userDepositPoolA[msg.sender];
      userRefund = (userDeposit * lot.refundRatioPoolB) / ratioPrecision;
    }

    lot.refunded[msg.sender] = true;
    IERC20(collateralToken).transfer(msg.sender, userRefund);
  }

  function resolveLot(uint256 _lotId) external {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(!lot.resolved, "already resolved");
    require(block.timestamp >= (lot.startEpoch + lot.duration), "too early");

    uint256 resolvePriceTokenA = uint256(
      IPriceFeed(priceFeed).getPrice(lot.tokenA)
    );
    uint256 resolvePriceTokenB = uint256(
      IPriceFeed(priceFeed).getPrice(lot.tokenB)
    );

    uint256 finalSizeTokenA = (lot.startSize * resolvePriceTokenA) /
      lot.startPriceTokenA;
    uint256 finalSizeTokenB = (lot.startSize * resolvePriceTokenB) /
      lot.startPriceTokenB;
    uint256 sizeDelta = abs(int256(finalSizeTokenA) - int256(finalSizeTokenB));
    uint256 delta = min(sizeDelta, lot.startSize);

    lot.totalClaimPoolA = lot.startSize;
    lot.totalClaimPoolB = lot.startSize;
    uint256 feeAmount = (delta * feePercentage) / 100;

    if (finalSizeTokenA > finalSizeTokenB) {
      lot.totalClaimPoolA += (delta - feeAmount);
      lot.totalClaimPoolB -= delta;
      emit LotResolved(
        _lotId,
        lot.tokenA,
        resolvePriceTokenA,
        resolvePriceTokenB
      );
    } else {
      lot.totalClaimPoolB += (delta - feeAmount);
      lot.totalClaimPoolA -= delta;
      emit LotResolved(
        _lotId,
        lot.tokenB,
        resolvePriceTokenA,
        resolvePriceTokenB
      );
    }

    totalFee += feeAmount;
    emit FeeCollected(_lotId, feeAmount);
    lot.resolved = true;
  }

  function withdrawClaim(uint256 _lotId) external returns (bool isSuccessful) {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(!lot.claimed[msg.sender], "already claimed");
    require(
      lot.userDepositPoolA[msg.sender] > 0 ||
        lot.userDepositPoolB[msg.sender] > 0,
      "not participated in lot"
    );

    uint256 claimRatio;
    uint256 claimAmount;

    if (lot.userDepositPoolA[msg.sender] > 0) {
      claimRatio =
        (lot.userDepositPoolA[msg.sender] * ratioPrecision) /
        lot.totalDepositPoolA;
      claimAmount = (claimRatio * lot.totalClaimPoolA) / ratioPrecision;
    } else {
      claimRatio =
        (lot.userDepositPoolB[msg.sender] * ratioPrecision) /
        lot.totalDepositPoolB;
      claimAmount = (claimRatio * lot.totalClaimPoolB) / ratioPrecision;
    }

    lot.claimed[msg.sender] = true;
    isSuccessful = IERC20(collateralToken).transfer(msg.sender, claimAmount);
  }

  function withdrawFee() external onlyOwner returns (bool isSuccessful) {
    uint256 totalFeeCopy = totalFee;
    totalFee = 0;
    isSuccessful = IERC20(collateralToken).transfer(msg.sender, totalFeeCopy);
    require(isSuccessful, "transfer failed");
  }

  // utils
  function min(uint256 x, uint256 y) private pure returns (uint256) {
    return x > y ? y : x;
  }

  function abs(int256 x) private pure returns (uint256) {
    return uint256(x >= 0 ? x : -x);
  }

  function compareStrings(string memory a, string memory b)
    public
    pure
    returns (bool)
  {
    return (keccak256(abi.encodePacked((a))) ==
      keccak256(abi.encodePacked((b))));
  }
}