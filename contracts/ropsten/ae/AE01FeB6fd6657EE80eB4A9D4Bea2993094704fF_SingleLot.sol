// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./IPriceFeed.sol";
import "./ILot.sol";

contract SingleLot is Ownable, ILot {
  address private priceFeed;

  address private collateralToken;

  mapping(address => int256) private balances;

  uint256 private feePercentage;

  struct Lot {
    string tokenA;
    string tokenB;
    address userA;
    address userB;
    int256 size;
    uint256 duration;
    uint256 expireEpoch;
    uint256 joinEpoch;
    int256 joinPriceTokenA;
    int256 joinPriceTokenB;
  }

  // lotId -> lot
  mapping(uint256 => Lot) private lots;

  uint256 private lastLotId;

  event LotCreated(
    uint256 lotId,
    string tokenA,
    string tokenB,
    address userA,
    int256 size,
    uint256 expireEpoch,
    uint256 duration
  );

  event LotJoined(
    uint256 lotId,
    address userB,
    int256 joinPriceTokenA,
    int256 joinPriceTokenB
  );

  event LotResolved(
    uint256 lotId,
    string winningToken,
    int256 resolvePriceTokenA,
    int256 resolvePriceTokenB
  );

  event Xfer(address user, int256 value);

  constructor(
    address _priceFeed,
    address _collateralToken,
    uint256 _feePercentage
  ) {
    priceFeed = _priceFeed;
    collateralToken = _collateralToken;
    feePercentage = _feePercentage;
  }

  function updateBalance(address _user, int256 _amount) internal {
    balances[_user] += _amount;
    emit Xfer(_user, _amount);
  }

  function depositCollateral(int256 _amount)
    internal
    returns (bool isSuccessful)
  {
    int256 balanceAmount = min(_amount, balances[msg.sender]);
    updateBalance(msg.sender, -balanceAmount);

    isSuccessful = IERC20(collateralToken).transferFrom(
      msg.sender,
      address(this),
      uint256(_amount - balanceAmount)
    );
    require(isSuccessful, "transfer failed");
  }

  function createLot(
    string memory _tokenA,
    string memory _tokenB,
    int256 _size,
    uint256 _duration,
    uint256 _expireEpoch
  ) external {
    require(
      keccak256(bytes(_tokenA)) != keccak256(bytes(_tokenB)),
      "identical token addresses"
    );
    require(depositCollateral(_size), "insufficient balance");

    Lot memory lot = Lot({
      tokenA: _tokenA,
      tokenB: _tokenB,
      userA: msg.sender,
      userB: address(0),
      size: _size,
      duration: _duration,
      expireEpoch: _expireEpoch,
      joinEpoch: 0,
      joinPriceTokenA: 0,
      joinPriceTokenB: 0
    });

    lots[++lastLotId] = lot;

    emit LotCreated(
      lastLotId,
      lot.tokenA,
      lot.tokenB,
      lot.userA,
      lot.size,
      lot.expireEpoch,
      lot.duration
    );
  }

  function joinLot(uint256 _lotId) external {
    Lot storage lot = lots[_lotId];

    require(lot.userA != address(0), "invalid lot id");
    require(block.timestamp < lot.expireEpoch, "expired lot");
    require(depositCollateral(lot.size), "insufficient balance");

    lot.userB = msg.sender;
    lot.joinPriceTokenA = IPriceFeed(priceFeed).getPrice(lot.tokenA);
    lot.joinPriceTokenB = IPriceFeed(priceFeed).getPrice(lot.tokenB);
    lot.joinEpoch = block.timestamp;

    emit LotJoined(_lotId, lot.userB, lot.joinPriceTokenA, lot.joinPriceTokenB);
  }

  function resolveLot(uint256 _lotId) external {
    Lot memory lot = lots[_lotId];

    require(lot.userA != address(0), "invalid lot id");
    require(lot.userB != address(0), "lot not joined");
    uint256 resolveTime = lot.joinEpoch + lot.duration;
    require(block.timestamp >= resolveTime, "too early");

    int256 resolvePriceTokenA = IPriceFeed(priceFeed).getHistoricalPrice(
      lot.tokenA,
      resolveTime
    );
    int256 resolvePriceTokenB = IPriceFeed(priceFeed).getHistoricalPrice(
      lot.tokenB,
      resolveTime
    );

    int256 finalSizeTokenA = (lot.size * resolvePriceTokenA) /
      lot.joinPriceTokenA;
    int256 finalSizeTokenB = (lot.size * resolvePriceTokenB) /
      lot.joinPriceTokenB;
    int256 sizeDelta = abs(finalSizeTokenA - finalSizeTokenB);
    int256 delta = min(sizeDelta, lot.size);
    int256 feeAmount = (delta * int256(feePercentage)) / 100;

    int256 amountUserA = lot.size;
    int256 amountUserB = lot.size;

    if (finalSizeTokenA > finalSizeTokenB) {
      amountUserA += (delta - feeAmount);
      amountUserB -= delta;
      emit LotResolved(
        _lotId,
        lot.tokenA,
        resolvePriceTokenA,
        resolvePriceTokenB
      );
    } else {
      amountUserB += (delta - feeAmount);
      amountUserA -= delta;
      emit LotResolved(
        _lotId,
        lot.tokenB,
        resolvePriceTokenA,
        resolvePriceTokenB
      );
    }

    delete lots[_lotId];

    updateBalance(lot.userA, amountUserA);
    updateBalance(lot.userB, amountUserB);
    updateBalance(address(this), feeAmount);
  }

  function withdrawBalance() external returns (bool isSuccessful) {
    int256 amount = balances[msg.sender];
    updateBalance(msg.sender, -amount);
    isSuccessful = IERC20(collateralToken).transfer(
      msg.sender,
      uint256(amount)
    );
    require(isSuccessful, "transfer failed");
  }

  function withdrawFee() external onlyOwner returns (bool isSuccessful) {
    int256 feeAmount = balances[address(this)];
    updateBalance(address(this), -feeAmount);
    isSuccessful = IERC20(collateralToken).transfer(
      msg.sender,
      uint256(feeAmount)
    );
    require(isSuccessful, "transfer failed");
  }

  // utils
  function min(int256 x, int256 y) private pure returns (int256) {
    return x > y ? y : x;
  }

  function abs(int256 x) private pure returns (int256) {
    return int256(x >= 0 ? x : -x);
  }
}