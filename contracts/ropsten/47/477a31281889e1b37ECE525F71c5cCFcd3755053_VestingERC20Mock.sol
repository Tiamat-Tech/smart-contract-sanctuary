// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * Mock version of VestingERC20.
 * Cliff and duration periods are set in days.
 * Claim interval is 1 hour.
 */

contract VestingERC20Mock is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable beneficiary;

    uint256 public immutable startTime;
    uint256 public immutable cliffDays;
    uint256 public immutable durationDays;

    uint256 public totalAmount;
    uint256 private _claimedAmount;
    uint256 private _lastClaimTime;

    // ERC20 token address.
    IERC20 public immutable token;

    bool public initialDeposited;

    event InitialDeposited(address indexed operator, uint256 amount);
    event Claimed(uint256 amount);

    constructor(
        IERC20 erc20_,
        address beneficiary_,
        uint256 cliffDays_,
        uint256 durationDays_
    )
    {
        token = erc20_;
        beneficiary = beneficiary_;
        startTime = block.timestamp;
        cliffDays = cliffDays_;
        durationDays = durationDays_;
    }

    /**************************|
    |          Vesting         |
    |_________________________*/

    /**
     * @dev Deposit the initial funds to the vesting contract.
     * Before using this function the `owner` needs to do an allowance from the `owner` to the vesting contract.
     * @param amount uint256 deposit amount.
     */
    function depositInitial(
        uint256 amount
    )
        public
    {
        require(!initialDeposited, "VestingERC20Mock#depositInitial: ALREADY_INITIAL_DEPOSITED");
        require(amount > 0, "VestingERC20Mock#depositInitial: AMOUNT_INVALID");
        token.safeTransferFrom(msg.sender, address(this), amount);
        totalAmount = amount;
        initialDeposited = true;

        emit InitialDeposited(msg.sender, amount);
    }

    /**
     * @dev Claim.
     * @param amount uint256 claim amount.
     */
    function claim(
        uint256 amount
    )
        public
        nonReentrant
    {
        require(msg.sender == beneficiary, "VestingERC20Mock#claim: CALLER_NO_BENEFICIARY");
        require(block.timestamp >= startTime.add(cliffDays * 1 days), "VestingERC20Mock#claim: CLIFF_PERIOD");
        require(block.timestamp.sub(_lastClaimTime) >= 1 hours, "VestingERC20Mock#claim: WITHIN_A_HOUR_FROM_LAST_CLAIM");
        require(amount > 0, "VestingERC20Mock#claim: AMOUNT_INVALID");
        require(amount <= getAvailableClaimAmount(), "VestingERC20Mock#claim: AVAILABLE_CLAIM_AMOUNT_EXCEEDED");

        _claimedAmount = _claimedAmount.add(amount);
        _lastClaimTime = block.timestamp;
        token.safeTransfer(beneficiary, amount);

        emit Claimed(amount);
    }

    /**
     * @dev Get vested amount.
     */
    function getVestedAmount()
        public
        view
        returns (uint256)
    {
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= startTime.add(durationDays * 1 days)) {
            return totalAmount;
        } else {
            return totalAmount.mul(block.timestamp.sub(startTime)).div(durationDays * 1 days);
        }
    }

    /**
     * @dev Get available claim amount.
     * Equals to total vested amount - claimed amount.
     */
    function getAvailableClaimAmount()
        public
        view
        returns (uint256)
    {
        return getVestedAmount().sub(_claimedAmount);
    }
}