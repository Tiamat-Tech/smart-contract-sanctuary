// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "./IPriceFeed.sol";
import "./AbstractLot.sol";

contract SingleLot is AbstractLot {
  mapping(address => uint256) private balances;

  struct Lot {
    string tokenA;
    string tokenB;
    address userA;
    address userB;
    uint256 size;
    uint256 duration;
    uint256 expireEpoch;
    uint256 joinEpoch;
    uint256 joinPriceTokenA;
    uint256 joinPriceTokenB;
  }

  // lotId -> lot
  mapping(uint256 => Lot) private lots;

  event LotCreated(
    uint256 lotId,
    string tokenA,
    string tokenB,
    address userA,
    uint256 size,
    uint256 expireEpoch,
    uint256 duration
  );

  event LotJoined(
    uint256 lotId,
    address userB,
    uint256 joinPriceTokenA,
    uint256 joinPriceTokenB
  );

  event LotResolved(
    uint256 lotId,
    string winningToken,
    uint256 resolvePriceTokenA,
    uint256 resolvePriceTokenB
  );

  // emitted when user's unlocked balance is updated
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

  function increaseBalance(address _user, uint256 _amount) internal {
    balances[_user] += _amount;
    emit Xfer(_user, int256(_amount));
  }

  function decreaseBalance(address _user, uint256 _amount) internal {
    balances[_user] += _amount;
    emit Xfer(_user, -1 * int256(_amount));
  }

  function depositCollateral(uint256 _amount)
    internal
    returns (bool isSuccessful)
  {
    uint256 balanceAmount = min(_amount, balances[msg.sender]);
    decreaseBalance(msg.sender, balanceAmount);

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
    uint256 _size,
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

  function resolveLot(uint256 _lotId) external override {
    Lot memory lot = lots[_lotId];

    require(lot.userA != address(0), "invalid lot id");
    require(lot.userB != address(0), "lot not joined");
    uint256 resolveTime = lot.joinEpoch + lot.duration;
    require(block.timestamp >= resolveTime, "too early");

    uint256 resolvePriceTokenA = IPriceFeed(priceFeed).getHistoricalPrice(
      lot.tokenA,
      resolveTime
    );
    uint256 resolvePriceTokenB = IPriceFeed(priceFeed).getHistoricalPrice(
      lot.tokenB,
      resolveTime
    );

    uint256 finalSizeTokenA = (lot.size * resolvePriceTokenA) /
      lot.joinPriceTokenA;
    uint256 finalSizeTokenB = (lot.size * resolvePriceTokenB) /
      lot.joinPriceTokenB;
    uint256 sizeDelta = abs(int256(finalSizeTokenA) - int256(finalSizeTokenB));
    uint256 delta = min(sizeDelta, lot.size);
    uint256 feeAmount = (delta * uint256(feePercentage)) / 100;

    uint256 amountUserA = lot.size;
    uint256 amountUserB = lot.size;

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

    increaseBalance(lot.userA, amountUserA);
    increaseBalance(lot.userB, amountUserB);
    increaseBalance(address(this), feeAmount);
  }

  function withdrawBalance() external returns (bool isSuccessful) {
    uint256 amount = balances[msg.sender];
    decreaseBalance(msg.sender, amount);
    isSuccessful = IERC20(collateralToken).transfer(msg.sender, amount);
    require(isSuccessful, "transfer failed");
  }

  function withdrawFee() external onlyOwner returns (bool isSuccessful) {
    uint256 feeAmount = balances[address(this)];
    decreaseBalance(address(this), feeAmount);
    isSuccessful = IERC20(collateralToken).transfer(msg.sender, feeAmount);
    require(isSuccessful, "transfer failed");
  }
}