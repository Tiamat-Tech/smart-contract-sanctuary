//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./CyanWrappedNFTV1.sol";

contract CyanPaymentPlanV1 is AccessControl, ReentrancyGuard {
    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");

    struct PaymentPlan {
        uint8 totalNumberOfPayments;
        uint8 counterPaidPayments;
        uint256[] amounts;
        uint256[] dueDates;
    }

    mapping(address => mapping(uint256 => PaymentPlan)) public _paymentPlan;

    constructor() {
        // console.log("Deploying a CyanPaymentPlan sender: %s", msg.sender);
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CYAN_ROLE, msg.sender);
    }

    function createPaymentPlan(
        address wNFTContract,
        uint256 wNFTTokenId,
        PaymentPlan memory paymentPlan
    ) public nonReentrant onlyRole(CYAN_ROLE) {
        // console.log(
        //     "Creating payment plan for wNFTContract:, wNFTTokenId:, msg.sender: ",
        //     wNFTContract,
        //     wNFTTokenId,
        //     msg.sender
        // );

        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments == 0,
            "Payment plan already exists"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments == 0,
            "Payment plan already exists"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].amounts.length == 0,
            "Payment plan already exists"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].dueDates.length == 0,
            "Payment plan already exists"
        );
        require(
            paymentPlan.totalNumberOfPayments > 0,
            "Total number of payments must be positive integer"
        );
        require(
            paymentPlan.totalNumberOfPayments <= 18,
            "Too many scheduled payments"
        );
        require(
            paymentPlan.amounts.length == paymentPlan.dueDates.length,
            "Length of amounts and dueDates are different"
        );
        require(
            paymentPlan.amounts.length == paymentPlan.totalNumberOfPayments,
            "Length of amounts and totalNumberOfPayments are different"
        );
        require(
            paymentPlan.counterPaidPayments == 0,
            "Non zero counterPaidPayments"
        );
        for (uint256 ind = 0; ind < paymentPlan.totalNumberOfPayments; ind++) {
            require(
                paymentPlan.dueDates[ind] > block.timestamp,
                "Due dates must be in the future"
            );
            if (ind > 0) {
                require(
                    paymentPlan.dueDates[ind - 1] < paymentPlan.dueDates[ind],
                    "Due dates have wrong ordering"
                );
            }
        }
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == true,
            "Token doesn't exists"
        );

        _paymentPlan[wNFTContract][wNFTTokenId] = paymentPlan;
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

        _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments =
            curPaymentIndex +
            1;

        if (
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments ==
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments
        ) {
            CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
            _cyanWrappedNFTV1.unwrap(
                wNFTTokenId,
                /* isDefaulted = */
                false
            );
            delete _paymentPlan[wNFTContract][wNFTTokenId];
        }
    }

    // TODO(Naba): cleanup this
    function getPaymentPlan(address wNFTContract, uint256 wNFTTokenId)
        public
        view
        returns (uint256)
    {
        // console.log(
        //     "Called getPaymentPlan for\n\twNFTContract: %s,\n\twNFTTokenId: %s",
        //     wNFTContract,
        //     wNFTTokenId
        // );
        // console.log(
        //     "\ttotalNumberOfPayments: %s,\n\tcounterPaidPayments: %s,\n\tamountsLen: %s",
        //     _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments,
        //     _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments,
        //     _paymentPlan[wNFTContract][wNFTTokenId].amounts.length
        // );
        // Returning counterPaidPayments just for testing
        return _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments;
    }
}