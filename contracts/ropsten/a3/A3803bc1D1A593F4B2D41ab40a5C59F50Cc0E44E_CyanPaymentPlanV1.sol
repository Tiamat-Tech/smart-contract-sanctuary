//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./CyanWrappedNFTV1.sol";
import "./CyanVaultV1.sol";

contract CyanPaymentPlanV1 is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");
    uint256 private _claimableServiceFee;

    struct PaymentPlan {
        address createdUserAddress;
        uint256 createdDate;
        uint8 totalNumberOfPayments;
        uint8 counterPaidPayments;
        uint256 amount;
        uint256 interestRate;
    }

    mapping(address => mapping(uint256 => PaymentPlan)) public _paymentPlan;

    constructor() {
        // console.log("Deploying a CyanPaymentPlan sender: %s", msg.sender);
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _claimableServiceFee = 0;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CYAN_ROLE, msg.sender);
    }

    /**
     * @notice Create BNPL payment plan
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     * @param amount Original price of the token
     * @param interestRate Cyan interest rate
     */
    function createBNPLPaymentPlan(
        address wNFTContract,
        uint256 wNFTTokenId,
        uint256 amount,
        uint256 interestRate
    ) public payable nonReentrant {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments == 0,
            "Payment plan already exists"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments == 0,
            "Payment plan already exists"
        );
        require(amount > 0, "Price of token is non-positive");
        require(interestRate > 0, "Interest rate is non-positive");
        require(msg.value > 0, "Downpayment amount is non-positive");

        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == false,
            "Token is already wrapped"
        );

        _paymentPlan[wNFTContract][wNFTTokenId] = PaymentPlan(
            msg.sender,
            block.timestamp,
            4,
            1,
            amount,
            interestRate
        );

        (, , , uint256 currentPayment, ) = getNextBNPLPayment(
            wNFTContract,
            wNFTTokenId
        );

        require(currentPayment == msg.value, "Downpayment amount incorrect");
    }

    /**
     * @notice Activating a BNPL payment plan
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     */
    function activateBNPL(address wNFTContract, uint256 wNFTTokenId)
        public
        nonReentrant
        onlyRole(CYAN_ROLE)
    {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments == 1,
            "Only downpayment must be paid "
        );
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == false,
            "Wrapped token exist"
        );

        (
            uint256 payAmountForToken,
            uint256 payAmountForInterest,
            uint256 payAmountForService,
            ,

        ) = getNextBNPLPayment(wNFTContract, wNFTTokenId);

        _cyanWrappedNFTV1.wrap(
            _paymentPlan[wNFTContract][wNFTTokenId].createdUserAddress,
            wNFTTokenId
        );

        _claimableServiceFee += payAmountForService;

        address _cyanVaultAddress = _cyanWrappedNFTV1.getCyanVaultAddress();
        transferCyanVaultPayment(
            _cyanVaultAddress,
            payAmountForToken,
            payAmountForInterest
        );
    }

    /**
     * @notice Liquidate defaulted payment plan
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     * @param estimatedTokenValue Estimated value of defaulted NFT
     */
    function liquidateBNPL(
        address wNFTContract,
        uint256 wNFTTokenId,
        uint256 estimatedTokenValue
    ) public nonReentrant onlyRole(CYAN_ROLE) {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments >
                _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments + 1,
            "Total payment done"
        );
        (, , , , uint256 dueDate) = getNextBNPLPayment(
            wNFTContract,
            wNFTTokenId
        );

        require(dueDate < block.timestamp, "Next payment is still due");

        uint256 unpaidAmount = 0;
        for (
            ;
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments <
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments;
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments =
                _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments +
                1
        ) {
            (uint256 payAmountForToken, , , , ) = getNextBNPLPayment(
                wNFTContract,
                wNFTTokenId
            );
            unpaidAmount += payAmountForToken;
        }
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

        address _cyanVaultAddress = _cyanWrappedNFTV1.getCyanVaultAddress();
        require(_cyanVaultAddress != address(0), "Cyan vault has zero address");
        CyanVaultV1 _cyanVaultV1 = CyanVaultV1(_cyanVaultAddress);
        _cyanVaultV1.nftDefaulted(unpaidAmount, estimatedTokenValue);
    }

    /**
     * @notice Make a payment for the payment plan
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     */
    function payBNPL(address wNFTContract, uint256 wNFTTokenId)
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

        (
            uint256 payAmountForToken,
            uint256 payAmountForInterest,
            uint256 payAmountForService,
            uint256 currentPayment,
            uint256 dueDate
        ) = getNextBNPLPayment(wNFTContract, wNFTTokenId);

        _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments =
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments +
            1;

        require(currentPayment == msg.value, "Wrong payment amount");
        require(dueDate >= block.timestamp, "Payment due date is passed");
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == true,
            "Wrapped token doesn't exist"
        );

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
        address _cyanVaultAddress = _cyanWrappedNFTV1.getCyanVaultAddress();

        _claimableServiceFee += payAmountForService;
        transferCyanVaultPayment(
            _cyanVaultAddress,
            payAmountForToken,
            payAmountForInterest
        );
    }

    /**
     * @notice Reject the payment plan
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     */
    function rejectBNPLPaymentPlan(address wNFTContract, uint256 wNFTTokenId)
        public
        nonReentrant
        onlyRole(CYAN_ROLE)
    {
        console.log(
            "Rejecting a payment plan wNFTContract: %s, wNFTTokenId: %s",
            wNFTContract,
            wNFTTokenId
        );

        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].counterPaidPayments == 1,
            "Payment done other than downpayment for this plan"
        );
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        require(
            _cyanWrappedNFTV1.exists(wNFTTokenId) == false,
            "Wrapped token exists"
        );

        (, , , uint256 currentPayment, ) = getNextBNPLPayment(
            wNFTContract,
            wNFTTokenId
        );

        // Returning downpayment to created user address
        payable(_paymentPlan[wNFTContract][wNFTTokenId].createdUserAddress)
            .transfer(currentPayment);
        delete _paymentPlan[wNFTContract][wNFTTokenId];
    }

    /**
     * @notice Return BNPL payment amount
     * @param amount Wrapped NFT contract address
     * @param interestRate Wrapped NFT token ID
     * @return Next payment amount for token
     * @return Total payment amount for interest fee
     * @return Next payment amount for interest fee
     * @return Total payment amount for service fee
     * @return Next payment amount for service fee
     * @return Next payment amount
     */
    function calculateIndividualPayments(uint256 amount, uint256 interestRate)
        private
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        // Payment amount for token price payment approx 25% of amount
        uint256 payAmountForToken = amount.div(4);

        // Calculating interest fee
        uint256 interestFee = (amount.mul(interestRate)).div(100);
        // Payment amount for interest fee payment approx 25% of interestFee
        uint256 payAmountForInterest = interestFee.div(4);

        // Calculating 2.5% service fee
        uint256 serviceFee = amount.div(40);
        // Payment amount for service fee payment approx 25% of serviceFee
        uint256 payAmountForService = serviceFee.div(4);

        // Downpayment amount
        uint256 currentPayment = payAmountForToken +
            payAmountForInterest +
            payAmountForService;

        return (
            payAmountForToken,
            interestFee,
            payAmountForInterest,
            serviceFee,
            payAmountForService,
            currentPayment
        );
    }

    /**
     * @notice Return BNPL payment amount
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     * @return Next payment amount for token
     * @return Next payment amount for interest Fee
     * @return Next payment amount for service Fee
     * @return Next payment amount
     * @return Due date
     */
    function getNextBNPLPayment(address wNFTContract, uint256 wNFTTokenId)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        PaymentPlan memory plan = _paymentPlan[wNFTContract][wNFTTokenId];
        (
            uint256 payAmountForToken,
            uint256 interestFee,
            uint256 payAmountForInterest,
            uint256 serviceFee,
            uint256 payAmountForService,
            uint256 currentPayment
        ) = calculateIndividualPayments(plan.amount, plan.interestRate);
        if (plan.counterPaidPayments == plan.totalNumberOfPayments) {
            // Last payment
            currentPayment =
                plan.amount -
                payAmountForToken.mul(3) +
                interestFee -
                payAmountForInterest.mul(3) +
                serviceFee -
                payAmountForService.mul(3);
        }

        return (
            payAmountForToken,
            payAmountForInterest,
            payAmountForService,
            currentPayment,
            plan.createdDate + plan.counterPaidPayments * 31 days
        );
    }

    /**
     * @notice Transfer earned amount to Cyan Vault
     * @param cyanVaultAddress Original price of the token
     * @param paidTokenPayment Paid token payment
     * @param paidInterestFee Paid interest fee
     */
    function transferCyanVaultPayment(
        address cyanVaultAddress,
        uint256 paidTokenPayment,
        uint256 paidInterestFee
    ) private {
        require(cyanVaultAddress != address(0), "Cyan vault has zero address");
        CyanVaultV1 _cyanVaultV1 = CyanVaultV1(cyanVaultAddress);
        _cyanVaultV1.earn{value: paidTokenPayment + paidInterestFee}(
            paidTokenPayment,
            paidInterestFee
        );
    }

    /**
     * @notice Return expected payment plan for given price and interest rate
     * @param amount Original price of the token
     * @param interestRate Interest rate
     * @return Original price of the token
     * @return Interest Fee
     * @return Service Fee
     * @return Downpayment amount
     * @return Total payment amount
     */
    function getExpectedPaymentPlan(uint256 amount, uint256 interestRate)
        public
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            ,
            uint256 interestFee,
            ,
            uint256 serviceFee,
            ,
            uint256 currentPayment
        ) = calculateIndividualPayments(amount, interestRate);

        uint256 totalPayment = amount + interestFee + serviceFee;
        return (amount, interestFee, serviceFee, currentPayment, totalPayment);
    }

    /**
     * @notice Check if payment plan is pending
     * @param wNFTContract Wrapped NFT contract address
     * @param wNFTTokenId Wrapped NFT token ID
     */
    function isPendingPaymentPlan(address wNFTContract, uint256 wNFTTokenId)
        public
        view
        returns (bool)
    {
        require(
            _paymentPlan[wNFTContract][wNFTTokenId].totalNumberOfPayments != 0,
            "No payment plan found"
        );
        CyanWrappedNFTV1 _cyanWrappedNFTV1 = CyanWrappedNFTV1(wNFTContract);
        return _cyanWrappedNFTV1.exists(wNFTTokenId) == false;
    }

    /**
     * @notice Getting claimable service fee amount
     */
    function getClaimableServiceFee()
        public
        view
        onlyRole(CYAN_ROLE)
        returns (uint256)
    {
        return _claimableServiceFee;
    }

    /**
     * @notice Claiming collected service fee amount
     */
    function claimServiceFee() public onlyRole(CYAN_ROLE) {
        payable(msg.sender).transfer(_claimableServiceFee);
        _claimableServiceFee = 0;
    }
}