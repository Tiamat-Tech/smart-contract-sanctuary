// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "./IPriceFeed.sol";

contract SingleLot is Ownable {
    uint256 public totalFee;
    address public collateralToken;
    address public priceFeed;
    uint256 public feePercentage;
    uint256 public lastLotId;

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
        uint256 claimUserA;
        uint256 claimUserB;
        bool depositWithdrawn;
        bool resolved;
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

    event DepositWithdrawn(uint256 lotId, address user, uint256 amount);

    event ClaimWithdrawn(uint256 lotId, address user, uint256 amount);

    event FeeWithdrawn(uint256 amount);

    constructor(
        address _priceFeed,
        address _collateralToken,
        uint256 _feePercentage
    ) public {
        priceFeed = _priceFeed;
        collateralToken = _collateralToken;
        feePercentage = _feePercentage;
    }

    // utils
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? y : x;
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -1 * x);
    }

    function depositCollateral(uint256 _amount)
        internal
        returns (bool isSuccessful)
    {
        isSuccessful = IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            uint256(_amount)
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
        require(_expireEpoch > block.timestamp, "expireEpoch in past");

        Lot storage lot = lots[++lastLotId];
        lot.tokenA = _tokenA;
        lot.tokenB = _tokenB;
        lot.userA = msg.sender;
        lot.size = _size;
        lot.duration = _duration;
        lot.expireEpoch = _expireEpoch;

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
        require(msg.sender != lot.userA, "creator can not join");

        lot.userB = msg.sender;
        lot.joinPriceTokenA = IPriceFeed(priceFeed).getPrice(lot.tokenA);
        lot.joinPriceTokenB = IPriceFeed(priceFeed).getPrice(lot.tokenB);
        lot.joinEpoch = block.timestamp;

        emit LotJoined(
            _lotId,
            lot.userB,
            lot.joinPriceTokenA,
            lot.joinPriceTokenB
        );
    }

    function resolveLot(uint256 _lotId) public {
        Lot storage lot = lots[_lotId];

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
        uint256 sizeDelta = abs(
            int256(finalSizeTokenA) - int256(finalSizeTokenB)
        );
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

        totalFee += feeAmount;

        lot.claimUserA = amountUserA;
        lot.claimUserB = amountUserB;
        lot.resolved = true;
    }

    function withdrawDeposit(uint256 _lotId)
        external
        returns (bool isSuccessful)
    {
        Lot storage lot = lots[_lotId];

        require(lot.userA != address(0), "invalid lot id");
        require(msg.sender == lot.userA, "only callable by creator");
        require(
            lot.userB == address(0) && block.timestamp >= lot.expireEpoch,
            "lot not expired"
        );
        require(!lot.depositWithdrawn, "already refunded");

        lot.depositWithdrawn = true;
        isSuccessful = IERC20(collateralToken).transfer(msg.sender, lot.size);
        require(isSuccessful, "transfer failed");
        emit DepositWithdrawn(_lotId, msg.sender, lot.size);
    }

    function withdrawClaim(uint256 _lotId)
        external
        returns (bool isSuccessful)
    {
        Lot storage lot = lots[_lotId];

        require(lot.userA != address(0), "invalid lot id");
        require(
            msg.sender == lot.userA || msg.sender == lot.userB,
            "only callable by lot users"
        );

        if (!lot.resolved) {
            resolveLot(_lotId);
        }

        uint256 amount;
        if (msg.sender == lot.userA) {
            amount = lot.claimUserA;
            lot.claimUserA = 0;
        } else if (msg.sender == lot.userB) {
            amount = lot.claimUserB;
            lot.claimUserB = 0;
        }
        isSuccessful = IERC20(collateralToken).transfer(msg.sender, amount);
        require(isSuccessful, "transfer failed");
        emit ClaimWithdrawn(_lotId, msg.sender, amount);
    }

    function withdrawFee() external onlyOwner returns (bool isSuccessful) {
        uint256 totalFeeCopy = totalFee;
        totalFee = 0;
        isSuccessful = IERC20(collateralToken).transfer(
            msg.sender,
            totalFeeCopy
        );
        require(isSuccessful, "transfer failed");
        emit FeeWithdrawn(totalFeeCopy);
    }
}