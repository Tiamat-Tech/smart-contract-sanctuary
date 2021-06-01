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

    uint8 decimals;
    uint256 public purchaseRate; // 0.1 BNB = 400000 UNITY
    uint256 public remainingAllocation; // In whole UNITY
    uint256 public remainingToCollect;
    bool public presaleActive;
    address payable private BNBreceiver;
    address payable private owner;

    IERC20 public unityToken;

    modifier onlyNotActive() {
        require(presaleActive == false, "The presale is still active and so you cant collect your Unity tokens yet.");
        _;
    }

    // Allocation Purchase Protection

    bool allocationPurchaseOccupied;

    modifier paymentModifiers() {
        // BNB: 10000000 0.1, 100000000 1, 1000000 0.1; ETH: 100000000000000000, 1000000000000000000, 100000000000000000
        require(presaleActive == true, "The presale is no longer active and all presale tokens have been sold.");
        require(msg.value >= 100000000000000000 && msg.value <= 1000000000000000000, "Min Purchase: 0.1 BNB, Max Purchase: 1 BNB");
        require(allocationPurchaseOccupied = false, "Someone else is buying UNITY tokens right now, please try again in a few minutes.");
        require(msg.value % 100000000000000000 == 0, "Only purchases divisible by 0.1 BNB can be made. Contact the team with this error msg.");
        _;
    }

    modifier lockTheAllocationPurchase() {
        allocationPurchaseOccupied = true;
        _;
        allocationPurchaseOccupied = false;
    }

    //;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can do this.");
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
        purchaseRate = rate; // 4,000,000 (0.1 BNB = 400,000)
        remainingAllocation = startingAllocation; // 400,000,000 UNITY in whole UNITY
        presaleActive = startPresale;
        BNBreceiver = _BNBreceiver;
        owner = payable(msg.sender);
        unityToken = IERC20(tokenAddress);
        allocationPurchaseOccupied = false;
        decimals = 9;
    }

    function getDecimalUnity(uint256 wholeUnity) private view returns(uint256) {
        return wholeUnity * (10 ** decimals);
    }
    
    function withdrawOutstanding(uint256 amount) public onlyOwner {
        unityToken.transfer(owner, getDecimalUnity(amount));

        emit allocationCollected(owner, amount);
    }

    function buyUnity() public payable paymentModifiers {
        allocationPurchase(payable(msg.sender), msg.value); // BNB in: BNB amount * 10**8
    }

    function allocationPurchase(address payable buyer, uint256 purchaseBNB) private lockTheAllocationPurchase {
        uint256 desiredPurchase = (purchaseBNB.div(1000000)).mul(purchaseRate); // 10000000 / 1000000 * 400000 = 4,000,000 per BNB

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
        uint256 unpurchasedUNITY = desiredPurchase.sub(purchaseAmount);
        uint256 unpurchasedBNB = (unpurchasedUNITY.div(purchaseRate)).mul(1000000);
        uint256 purchaseBNB = totalBNB.sub(unpurchasedBNB);
        executePurchase(_buyer, purchaseAmount, purchaseBNB);
        return unpurchasedBNB;
    }

    function executePurchase(address payable __buyer, uint256 amountUNITY, uint256 amountBNB) private {
        require((amountBNB.div(1000000)).mul(purchaseRate) == amountUNITY, "the purchase exchange rate is wrong");

        if (allocations[__buyer] == 0) {
            allocations[__buyer] = amountUNITY;
        } else {
            allocations[__buyer] += amountUNITY;
        }
        
        remainingAllocation -= amountUNITY;
        BNBreceiver.transfer(amountBNB); // Is the BNB paid into the contract already at this point?
        remainingToCollect += amountUNITY;

        emit purchaseMade(__buyer, amountUNITY, amountBNB);

    }

    function collectTokens() public onlyNotActive {
        require(allocations[msg.sender] != 0, "You have no tokens to collect");

        unityToken.transfer(msg.sender, getDecimalUnity(allocations[msg.sender]));

        emit allocationCollected(msg.sender, allocations[msg.sender]);

        remainingToCollect -= allocations[msg.sender];
        allocations[msg.sender] = 0;

    }

}