// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./IPriceFeed.sol";
import "./AbstractLot.sol";

contract MultiLot is AbstractLot {
  uint256 public constant RATIO_PRECISION = 100000;

  uint256 public totalFee;

  struct Lot {
    string tokenA;
    string tokenB;
    uint256 startEpoch;
    uint256 duration;
    address creator;
    mapping(address => uint256) userDepositPoolA;
    mapping(address => uint256) userDepositPoolB;
    // store total deposit size to avoid iterating over userDepositPool mapping
    uint256 totalDepositPoolA;
    uint256 totalDepositPoolB;
    // deposits should only be withdrawn once
    mapping(address => bool) depositWithdrawn;
    // refunds should only be processed once
    mapping(address => bool) refunded;
    // resolveLot should only be called once
    bool resolved;
    // claims should only be processed once
    mapping(address => bool) claimed;
    uint256 totalClaimPoolA;
    uint256 totalClaimPoolB;
  }

  // lotId -> lot
  mapping(uint256 => Lot) private lots;

  event LotCreated(
    uint256 lotId,
    string tokenA,
    string tokenB,
    uint256 startEpoch,
    uint256 duration,
    address creator
  );

  event LotJoined(uint256 lotId, string token, address user, uint256 size);

  event LotResolved(
    uint256 lotId,
    uint256 size,
    string winningToken,
    uint256 startPriceTokenA,
    uint256 startPriceTokenB,
    uint256 resolvePriceTokenA,
    uint256 resolvePriceTokenB
  );

  function getSize(Lot storage lot) internal view returns (uint256 size) {
    size = min(lot.totalDepositPoolA, lot.totalDepositPoolB);
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

    Lot storage lot = lots[++lastLotId];
    lot.tokenA = _tokenA;
    lot.tokenB = _tokenB;
    lot.startEpoch = _startEpoch;
    lot.duration = _duration;
    lot.creator = msg.sender;

    emit LotCreated(
      lastLotId,
      lot.tokenA,
      lot.tokenB,
      lot.startEpoch,
      lot.duration,
      lot.creator
    );

    joinLot(lastLotId, _tokenA, _size);
  }

  function joinLot(
    uint256 _lotId,
    string calldata _token,
    uint256 _size
  ) public {
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

  function resolveLot(uint256 _lotId) external override {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(!lot.resolved, "already resolved");
    require(block.timestamp >= (lot.startEpoch + lot.duration), "too early");

    uint256 size = getSize(lot);

    uint256 startPriceTokenA = uint256(
      IPriceFeed(priceFeed).getHistoricalPrice(lot.tokenA, lot.startEpoch)
    );
    uint256 startPriceTokenB = uint256(
      IPriceFeed(priceFeed).getHistoricalPrice(lot.tokenB, lot.startEpoch)
    );

    uint256 resolvePriceTokenA = uint256(
      IPriceFeed(priceFeed).getHistoricalPrice(
        lot.tokenA,
        lot.startEpoch + lot.duration
      )
    );
    uint256 resolvePriceTokenB = uint256(
      IPriceFeed(priceFeed).getHistoricalPrice(
        lot.tokenB,
        lot.startEpoch + lot.duration
      )
    );

    uint256 finalSizeTokenA = (size * resolvePriceTokenA) / startPriceTokenA;
    uint256 finalSizeTokenB = (size * resolvePriceTokenB) / startPriceTokenB;
    uint256 sizeDelta = abs(int256(finalSizeTokenA) - int256(finalSizeTokenB));
    uint256 delta = min(sizeDelta, size);

    lot.totalClaimPoolA = size;
    lot.totalClaimPoolB = size;
    uint256 feeAmount = (delta * feePercentage) / 100;

    if (finalSizeTokenA > finalSizeTokenB) {
      lot.totalClaimPoolA += (delta - feeAmount);
      lot.totalClaimPoolB -= delta;
      emit LotResolved(
        _lotId,
        size,
        lot.tokenA,
        startPriceTokenA,
        startPriceTokenB,
        resolvePriceTokenA,
        resolvePriceTokenB
      );
    } else {
      lot.totalClaimPoolB += (delta - feeAmount);
      lot.totalClaimPoolA -= delta;
      emit LotResolved(
        _lotId,
        size,
        lot.tokenB,
        startPriceTokenA,
        startPriceTokenB,
        resolvePriceTokenA,
        resolvePriceTokenB
      );
    }

    totalFee += feeAmount;
    lot.resolved = true;
  }

  function withdrawDeposit(uint256 _lotId)
    external
    returns (bool isSuccessful)
  {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(lot.userDepositPoolA[msg.sender] != 0, "not joined the lot");
    require(
      lot.totalDepositPoolB == 0 && block.timestamp >= lot.startEpoch,
      "lot not expired"
    );
    require(!lot.depositWithdrawn[msg.sender], "already withdrawn");

    lot.depositWithdrawn[msg.sender] = true;
    isSuccessful = IERC20(collateralToken).transfer(
      msg.sender,
      lot.userDepositPoolA[msg.sender]
    );
    require(isSuccessful, "transfer failed");
  }

  function withdrawRefund(uint256 _lotId) external {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(block.timestamp >= lot.startEpoch, "too early");
    require(!lot.refunded[msg.sender], "already refunded");

    uint256 refundAmount;
    uint256 size = getSize(lot);

    if (size < lot.totalDepositPoolA && lot.userDepositPoolA[msg.sender] > 0) {
      uint256 refundRatio = (RATIO_PRECISION * (lot.totalDepositPoolA - size)) /
        lot.totalDepositPoolA;
      refundAmount =
        (lot.userDepositPoolA[msg.sender] * refundRatio) /
        RATIO_PRECISION;
    } else if (
      size < lot.totalDepositPoolB && lot.userDepositPoolB[msg.sender] > 0
    ) {
      uint256 refundRatio = (RATIO_PRECISION * (lot.totalDepositPoolB - size)) /
        lot.totalDepositPoolB;
      refundAmount =
        (lot.userDepositPoolB[msg.sender] * refundRatio) /
        RATIO_PRECISION;
    }

    lot.refunded[msg.sender] = true;
    IERC20(collateralToken).transfer(msg.sender, refundAmount);
  }

  function withdrawClaim(uint256 _lotId) external returns (bool isSuccessful) {
    Lot storage lot = lots[_lotId];

    require(bytes(lot.tokenA).length != 0, "invalid lot id");
    require(lot.resolved, "too early");
    require(!lot.claimed[msg.sender], "already claimed");

    uint256 claimAmount;

    if (lot.userDepositPoolA[msg.sender] > 0) {
      uint256 claimRatio = (lot.userDepositPoolA[msg.sender] * RATIO_PRECISION) /
        lot.totalDepositPoolA;
      claimAmount = (claimRatio * lot.totalClaimPoolA) / RATIO_PRECISION;
    } else {
      uint256 claimRatio = (lot.userDepositPoolB[msg.sender] * RATIO_PRECISION) /
        lot.totalDepositPoolB;
      claimAmount = (claimRatio * lot.totalClaimPoolB) / RATIO_PRECISION;
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
}