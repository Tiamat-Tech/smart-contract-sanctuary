// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//-------------------------|| UnityFund.finance ||----------------------------\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\/\/\/\\//\\//\\//\\//\\//\\//\\/\/\/\/\/\/\/\/\/\/\\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

import '../libraries/IERC20.sol';
import '../libraries/SafeMath.sol';

contract UnityPresale {

    using SafeMath for uint256;

    mapping(address => uint256) public allocations;

    uint256 public purchaseRate;
    uint256 public remainingAllocation;
    uint256 public remainingToCollect;
    bool public presaleActive;
    address payable private BNBreceiver;
    address payable private owner;

    IERC20 public unityToken;

    modifier onlyNotActive() {
        require(presaleActive == false, "The presale is still active and so you can't collect your Unity tokens yet.");
        _;
    }

    // Allocation Purchase Protection

    bool allocationPurchaseOccupied;

    modifier paymentModifiers() {
        require(presaleActive == true, "The presale is no longer active and all presale tokens have been sold.");
        require(msg.value >= 0.1 ether && msg.value <= 1 ether, "Min Purchase: 0.1 BNB, Max Purchase: 1 BNB");
        require(allocationPurchaseOccupied = false, "Someone else is buying UNITY tokens right now, please try again in a few minutes.");
        _;
    }

    modifier lockTheAllocationPurchase() {
        allocationPurchaseOccupied = true;
        _;
        allocationPurchaseOccupied = false;
    }

    //;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event purchaseMade (
        address buyer,
        uint256 amountUNITY,
        uint256 amountBNB
    );

    event allocationCollected (
        address collector,
        uint256 amountUNITY
    );

    constructor (uint256 rate, uint256 startingAllocation, bool startPresale, address payable _BNBreceiver, address tokenAddress) {
        purchaseRate = rate;
        remainingAllocation = startingAllocation * 10**9;
        presaleActive = startPresale;
        BNBreceiver = _BNBreceiver;
        owner = payable(msg.sender);
        unityToken = IERC20(tokenAddress);
        allocationPurchaseOccupied = false;
    }

    function withdrawOutstanding(uint256 amount) public onlyOwner {
        unityToken.transfer(owner, amount);

        emit allocationCollected(owner, amount);
    }

    function buyUnity(uint256 amountInBNB) public payable paymentModifiers {
        allocationPurchase(payable(msg.sender), amountInBNB);
    }

    function allocationPurchase(address payable buyer, uint256 purchaseBNB) private lockTheAllocationPurchase {
        uint256 desiredPurchase = purchaseBNB.div(purchaseRate);

        if (desiredPurchase <= remainingAllocation) {
            completeFullPurchase(buyer, desiredPurchase, purchaseBNB);
        } else {
            uint256 refundedBNB = completePartialPurchase(buyer, desiredPurchase, purchaseBNB);
            buyer.transfer(refundedBNB);
            presaleActive = false;
        }
    }

    function completeFullPurchase(address payable _buyer, uint256 purchaseAmount, uint256 _purchaseBNB) private {
        executePurchase(_buyer, purchaseAmount, _purchaseBNB);
    }

    function completePartialPurchase(address payable _buyer, uint256 desiredPurchase, uint256 totalBNB) private returns(uint256) {
        uint256 purchaseAmount = remainingAllocation;
        uint256 unpurchasedUNITY = desiredPurchase - purchaseAmount;
        uint256 unpurchasedBNB = unpurchasedUNITY.mul(purchaseRate);
        uint256 purchaseBNB = totalBNB.sub(unpurchasedBNB);
        executePurchase(_buyer, purchaseAmount, purchaseBNB);
        return unpurchasedBNB;
    }

    function executePurchase(address payable __buyer, uint256 amountUNITY, uint256 amountBNB) private {
        require(amountUNITY.mul(purchaseRate) == amountBNB, "the purchase exchange rate is wrong");

        if (allocations[__buyer] == 0) {
            allocations[__buyer] = amountUNITY;
        } else {
            allocations[__buyer] += amountUNITY;
        }
        
        remainingAllocation -= amountUNITY;
        BNBreceiver.transfer(amountBNB);
        remainingToCollect += amountUNITY;

        emit purchaseMade(__buyer, amountUNITY, amountBNB);

    }

    function collectTokens() public onlyNotActive {
        require(allocations[msg.sender] != 0, "You have no tokens to collect");

        unityToken.transfer(msg.sender, allocations[msg.sender]);

        emit allocationCollected(msg.sender, allocations[msg.sender]);

        remainingToCollect -= allocations[msg.sender];
        allocations[msg.sender] = 0;

    }

}