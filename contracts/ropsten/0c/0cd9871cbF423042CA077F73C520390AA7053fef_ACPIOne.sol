//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./RealT.sol";
import "./IACPI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ACPIOne is IACPI, Ownable {
    address public highestBidder;
    uint256 public highestBid;

    uint256[] public results;

    mapping(address => uint256) pendingReturns;

    mapping(address => uint256) private _balance;

    uint256 private currentRound;

    RealT private realtERC20;

    constructor(address realtAddress) {
        realtERC20 = RealT(realtAddress);
        currentRound = 0;
    }

    modifier onlyAcpiOne() {
        require(realtERC20.getACPI() == 1, "Current ACPI is not ACPI 1");
        _;
    }

    /**
     * @dev Returns the amount of rounds per ACPI.
     */
    function totalRound() public pure override returns (uint256) {
        return 128;
    }

    /**
     * @dev Returns the amount of blocks per ACPI.
     */
    function roundTime() external pure override returns (uint256) {
        return 3;
    }

    /**
     * @dev Returns the amount of tokens invested by `account`.
     */
    function investOf(address account) public view override returns (uint256) {
        return _balance[account];
    }

    /**
     * @dev Start round of ACPI ending the last one.
     */
    function startRound()
        public
        override
        onlyOwner
        onlyAcpiOne
        returns (bool success)
    {
        currentRound += 1;
        if (highestBidder != address(0)) {
            _balance[highestBidder] += 1;
            realtERC20.mint(highestBidder, 1);
            results.push(highestBid);
        }
        highestBid = 0;
        highestBidder = address(0);

        return true;
    }

    function bid() external payable onlyAcpiOne returns (bool) {
        require(currentRound < totalRound(), "All the round have been done");

        require(
            msg.value > maxBid(),
            "bid amount should be higher than last bid"
        );
        if (highestBidder != address(0)) {
            // Refund the previously highest bidder.
            pendingReturns[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;
        return true;
    }

    function withdraw() external returns (bool) {
        require(
            pendingReturns[msg.sender] > 0,
            "You don't have any funds to withdraw!"
        );
        // It is important to set this to zero because the recipient
        // can call this function again as part of the receiving call
        // before `transfer` returns (see the remark above about
        // conditions -> effects -> interaction).
        pendingReturns[msg.sender] = 0;

        payable(msg.sender).transfer(pendingReturns[msg.sender]);

        return true;
    }

    function maxBid() public view returns (uint256) {
        return highestBid;
    }

    /**
     * @dev Returns the average value for target ACPI will be 0 until acpi end
     */
    function acpiPrice() external view override returns (uint256) {
        if (realtERC20.getACPI() <= 1) return 0;
        uint256 sum = 0;
        for (uint256 i = 0; i < results.length; i++) {
            sum += results[i];
        }
        return sum / results.length;
    }
}