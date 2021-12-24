//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./CyanWrappedNFTV1.sol";

contract CyanPaymentPlanV1 is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");

    struct PaymentPlan {
        uint8 totalNumberOfPayments;
        uint8 counterPaidPayments;
        uint256[4] amounts;
        uint256[4] dueDates;
    }

    mapping(address => mapping(uint256 => PaymentPlan)) public _paymentPlan;

    constructor() {
        // console.log("Deploying a CyanPaymentPlan sender: %s", msg.sender);
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CYAN_ROLE, msg.sender);
    }

    function createBNPLPaymentPlan(
        address wNFTContract,
        uint256 wNFTTokenId,
        uint256 priceOfToken,
        uint256 interestRate
    ) public payable nonReentrant {
        // console.log(
        //     "Creating BNPL payment plan for wNFTContract: %s, wNFTTokenId: %s, msg.sender: %s",
        //     wNFTContract,
        //     wNFTTokenId,
        //     msg.sender
        // );
        // console.log(
        //     "Price of token:, Interest rate:, msg.value: ",
        //     priceOfToken,
        //     interestRate,
        //     msg.value
        // );

        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments == 0,
            "Payment plan already exists"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments == 0,
            "Payment plan already exists"
        );
        require(priceOfToken > 0, "Price of token is non-positive");
        require(interestRate > 0, "Interest rate is non-positive");
        require(msg.value > 0, "Downpayment amount is non-positive");
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == false,
            "Token is already wrapped"
        );

        PaymentPlan memory newPaymentPlan = makePaymentPlan(
            priceOfToken,
            interestRate
        );

        require(
            newPaymentPlan.amounts[0] == msg.value,
            "Downpayment amount incorrect"
        );

        _paymentPlan[wNFTContract][wNFTTokenId] = newPaymentPlan;
    }

    function liquidate(address wNFTContract, uint256 wNFTTokenId)
        public
        nonReentrant
        onlyRole(CYAN_ROLE)
    {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments >
                _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments,
            "Total payment done"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].dueDates[
                _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments
            ] < block.timestamp,
            "Next payment is still due"
        );

        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == true,
            "Wrapped token doesn't exist"
        );
        _cyanWrappedNFTV1.unwrap(
            wNFTTokenId,
            /* isDefaulted = */
            true
        );
        delete _paymentPlan[wNFTContract][wNFTTokenId];
    }

    function pay(address wNFTContract, uint256 wNFTTokenId)
        public
        payable
        nonReentrant
    {
        // console.log(
        //     "Paying a payment for wNFTContract:, wNFTTokenId:, now: ",
        //     wNFTContract,
        //     wNFTTokenId,
        //     block.timestamp
        // );

        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments >
                _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments,
            "Total payment done"
        );
        uint8 curPaymentIndex = _paymentPlan[wNFTContract][wNFTTokenId]
            .counterPaidPayments;
        require(
            curPaymentIndex <
                _paymentPlan[wNFTContract][wNFTTokenId].amounts.length,
            "Index out of bounds"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].amounts[curPaymentIndex] ==
                msg.value,
            "Wrong payment amount"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].dueDates[
                _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments
            ] >= block.timestamp,
            "Payment due date is passed"
        );
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == true,
            "Wrapped token doesn't exist"
        );

        _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments =
            curPaymentIndex +
            1;

        if (
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments ==
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments
        ) {
            _cyanWrappedNFTV1.unwrap(
                wNFTTokenId,
                /* isDefaulted = */
                false
            );
            delete _paymentPlan[wNFTContract][wNFTTokenId];
        }
    }

    function getPaymentPlan(address wNFTContract, uint256 wNFTTokenId)
        public
        view
        returns (PaymentPlan memory)
    {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        return _paymentPlan[wNFTContract][wNFTTokenId];
    }

    function makePaymentPlan(uint256 priceOfToken, uint256 interestRate)
        public
        view
        returns (PaymentPlan memory)
    {
        // Calculating interest fee
        uint256 interestFee = (priceOfToken.mul(interestRate)).div(100);
        // Calculating 2.5% service fee
        uint256 serviceFee = priceOfToken.div(40);
        // Total payment
        uint256 totalPrice = priceOfToken + interestFee + serviceFee;
        // Payment amount for each payment approx 25% of totalPrice
        uint256 payAmount = totalPrice.div(4);

        console.log(
            "TotalPrice = %s, current amount = %s",
            totalPrice,
            payAmount
        );
        console.log(
            "priceOfToken = %s, interestFee = %s, serviceFee = %s",
            priceOfToken,
            interestFee,
            serviceFee
        );

        return
            PaymentPlan(
                4, // total number of payments
                1, // counter of completed payments including downpayment
                [
                    payAmount, // 25% downpayment
                    payAmount, // 25% payment
                    payAmount, // 25% payment
                    totalPrice - payAmount.mul(3) // remaining approx 25% payment
                ],
                [
                    block.timestamp, // downpayment date
                    block.timestamp + 31 days, // first payment due date
                    block.timestamp + 62 days, // second payment due date
                    block.timestamp + 93 days // third payment due date
                ]
            );
    }
}