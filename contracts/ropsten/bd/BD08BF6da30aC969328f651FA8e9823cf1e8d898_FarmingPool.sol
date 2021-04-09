// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;
pragma abicoder v2; // solhint-disable-line

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/Exponential.sol";
import "./libraries/IterableLoanMap.sol";
import "./interfaces/IAdapter.sol";
import "./interfaces/IBtoken.sol";
import "./interfaces/IFarmingPool.sol";
import "./interfaces/ITreasuryPool.sol";

contract FarmingPool is Pausable, ReentrancyGuard, IFarmingPool {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Exponential for uint256;
    using IterableLoanMap for IterableLoanMap.RateToLoanMap;

    struct RepaymentDetails {
        uint256 taxAmount;
        uint256 payableInterest;
        uint256 loanPrincipalToRepay;
        uint256 amountToReceive;
    }

    uint256 public constant NUM_FRACTION_BITS = 64;
    uint256 public constant SECONDS_IN_DAY = 86400;
    uint256 public constant DAYS_IN_YEAR = 365;
    uint256 public constant SECONDS_IN_YEAR = SECONDS_IN_DAY * DAYS_IN_YEAR;
    // https://github.com/crytic/slither/wiki/Detector-Documentation#too-many-digits
    // slither-disable-next-line too-many-digits
    uint256 public constant INTEREST_RATE_SLOPE_1 = 0x5555555555555555; // 1/3 in unsigned 64.64 fixzed-point number
    // https://github.com/crytic/slither/wiki/Detector-Documentation#variable-names-too-similar
    // slither-disable-next-line similar-names,too-many-digits
    uint256 public constant INTEREST_RATE_SLOPE_2 = 0xF0000000000000000; // 15 in unsigned 64.64 fixed-point number
    uint256 public constant INTEREST_RATE_INTEGER_POINT_1 = 10;
    // slither-disable-next-line similar-names
    uint256 public constant INTEREST_RATE_INTEGER_POINT_2 = 25;
    uint256 public constant PERCENT_100 = 100;
    // slither-disable-next-line too-many-digits
    uint256 public constant UTILISATION_RATE_POINT_1 = 0x320000000000000000; // 50% in unsigned 64.64 fixed-point number
    // slither-disable-next-line similar-names,too-many-digits
    uint256 public constant UTILISATION_RATE_POINT_2 = 0x5F0000000000000000; // 95% in unsigned 64.64 fixed-point number

    address public governanceAccount;
    address public underlyingAssetAddress;
    address public btokenAddress;
    address public treasuryPoolAddress;
    address public adapterAddress;
    uint256 public leverageFactor;
    uint256 public taxRate; // as percentage in unsigned integer

    uint256 public totalInterestEarned;
    uint256 public previousNettInterestEarning;

    mapping(address => uint256) private _totalTransferToAdapter;
    mapping(address => IterableLoanMap.RateToLoanMap) private _farmerLoans;
    IterableLoanMap.RateToLoanMap private _poolLoans;

    constructor(
        address underlyingAssetAddress_,
        address btokenAddress_,
        address treasuryPoolAddress_,
        uint256 leverageFactor_,
        uint256 taxRate_
    ) {
        require(
            underlyingAssetAddress_ != address(0),
            "0 underlying asset address"
        );
        require(btokenAddress_ != address(0), "0 BToken address");
        require(treasuryPoolAddress_ != address(0), "0 treasury pool address");
        require(leverageFactor_ >= 1, "leverage factor < 1");
        require(taxRate_ > 0, "0 tax rate");
        require(taxRate_ <= 100, "> 100%");

        governanceAccount = msg.sender;
        underlyingAssetAddress = underlyingAssetAddress_;
        btokenAddress = btokenAddress_;
        treasuryPoolAddress = treasuryPoolAddress_;
        leverageFactor = leverageFactor_;
        taxRate = taxRate_;
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "unauthorized");
        _;
    }

    function addLiquidity(uint256 amount) external override nonReentrant {
        require(amount > 0, "0 amount");
        require(!paused(), "paused");
        require(
            IERC20(underlyingAssetAddress).balanceOf(msg.sender) >= amount,
            "insufficient underlying asset"
        );

        uint256 utilisationRate =
            ITreasuryPool(treasuryPoolAddress).getUtilisationRate(); // in unsigned 64.64-bit fixed point number
        uint256 integerNominalAnnualRate =
            getBorrowNominalAnnualRate(utilisationRate);
        uint256 transferAmount = amount.mul(leverageFactor);
        _totalTransferToAdapter[msg.sender] = _totalTransferToAdapter[
            msg.sender
        ]
            .add(transferAmount);
        uint256 loanAmount = transferAmount.sub(amount);

        {
            // scope to avoid stack too deep errors
            (bool farmerKeyExists, IterableLoanMap.Loan memory farmerLoan) =
                _farmerLoans[msg.sender].tryGet(integerNominalAnnualRate);

            uint256 farmerSecondsSinceLastAccrual = 0;
            uint256 farmerAccrualTimestamp = block.timestamp;
            if (farmerKeyExists) {
                (
                    farmerSecondsSinceLastAccrual,
                    farmerAccrualTimestamp
                ) = getSecondsSinceLastAccrual(
                    block.timestamp,
                    farmerLoan._lastAccrualTimestamp
                );
            }

            uint256 farmerPresentValue = farmerLoan._principalWithInterest;
            uint256 farmerFutureValue = farmerPresentValue;
            if (farmerPresentValue > 0 && farmerSecondsSinceLastAccrual > 0) {
                farmerFutureValue = accruePerSecondCompoundInterest(
                    farmerPresentValue,
                    integerNominalAnnualRate,
                    farmerSecondsSinceLastAccrual
                );
            }

            farmerLoan._principalOnly = farmerLoan._principalOnly.add(
                loanAmount
            );
            farmerLoan._principalWithInterest = farmerFutureValue.add(
                loanAmount
            );
            farmerLoan._lastAccrualTimestamp = farmerAccrualTimestamp;

            // https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
            // slither-disable-next-line unused-return
            _farmerLoans[msg.sender].set(integerNominalAnnualRate, farmerLoan);
        }

        {
            // scope to avoid stack too deep errors
            (bool poolKeyExists, IterableLoanMap.Loan memory poolLoan) =
                _poolLoans.tryGet(integerNominalAnnualRate);

            uint256 poolSecondsSinceLastAccrual = 0;
            uint256 poolAccrualTimestamp = block.timestamp;
            if (poolKeyExists) {
                (
                    poolSecondsSinceLastAccrual,
                    poolAccrualTimestamp
                ) = getSecondsSinceLastAccrual(
                    block.timestamp,
                    poolLoan._lastAccrualTimestamp
                );
            }

            uint256 poolPresentValue = poolLoan._principalWithInterest;
            uint256 poolFutureValue = poolPresentValue;
            if (poolPresentValue > 0 && poolSecondsSinceLastAccrual > 0) {
                poolFutureValue = accruePerSecondCompoundInterest(
                    poolPresentValue,
                    integerNominalAnnualRate,
                    poolSecondsSinceLastAccrual
                );
            }

            poolLoan._principalOnly = poolLoan._principalOnly.add(loanAmount);
            poolLoan._principalWithInterest = poolFutureValue.add(loanAmount);
            poolLoan._lastAccrualTimestamp = poolAccrualTimestamp;

            // https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
            // slither-disable-next-line unused-return
            _poolLoans.set(integerNominalAnnualRate, poolLoan);
        }

        IERC20(underlyingAssetAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        ITreasuryPool(treasuryPoolAddress).loan(loanAmount);

        bool isApproved =
            IERC20(underlyingAssetAddress).approve(
                adapterAddress,
                transferAmount
            );
        require(isApproved, "approve failed");
        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
        // slither-disable-next-line reentrancy-events
        uint256 receiveQuantity =
            IAdapter(adapterAddress).depositUnderlyingToken(transferAmount);

        emit AddLiquidity(
            msg.sender,
            underlyingAssetAddress,
            amount,
            receiveQuantity,
            block.timestamp
        );

        IBtoken(btokenAddress).mint(msg.sender, receiveQuantity);
    }

    function removeLiquidity(uint256 amount) external override nonReentrant {
        require(amount > 0, "0 amount");
        require(!paused(), "paused");
        require(_totalTransferToAdapter[msg.sender] > 0, "no transfer");
        require(
            IBtoken(btokenAddress).balanceOf(msg.sender) >= amount,
            "insufficient BToken"
        );

        (
            uint256 farmerOutstandingInterest,
            uint256[] memory farmerIntegerInterestRates,
            IterableLoanMap.Loan[] memory farmerSortedLoans
        ) = accrueInterestForLoan(_farmerLoans[msg.sender]);

        require(
            farmerIntegerInterestRates.length == farmerSortedLoans.length,
            "farmer len diff"
        );

        (
            uint256[] memory poolIntegerInterestRates,
            IterableLoanMap.Loan[] memory poolSortedLoans
        ) =
            accrueInterestBasedOnInterestRates(
                _poolLoans,
                farmerIntegerInterestRates
            );

        require(
            poolIntegerInterestRates.length == poolSortedLoans.length,
            "pool len diff"
        );
        require(
            farmerIntegerInterestRates.length ==
                poolIntegerInterestRates.length,
            "farmer/pool len diff"
        );

        uint256 interestEarning = getInterestEarning(poolSortedLoans);

        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-2
        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
        // slither-disable-next-line reentrancy-benign,reentrancy-events
        uint256 receiveQuantity =
            IAdapter(adapterAddress).redeemWrappedToken(amount);

        RepaymentDetails memory repaymentDetails =
            calculateRepaymentDetails(
                amount,
                receiveQuantity,
                farmerOutstandingInterest
            );

        totalInterestEarned = totalInterestEarned.add(
            repaymentDetails.payableInterest
        );
        previousNettInterestEarning = interestEarning.sub(
            repaymentDetails.payableInterest
        );

        updateLoansForFarmerAndPool(
            farmerIntegerInterestRates,
            farmerSortedLoans,
            poolSortedLoans,
            repaymentDetails
        );

        emit RemoveLiquidity(
            msg.sender,
            underlyingAssetAddress,
            amount,
            receiveQuantity,
            repaymentDetails.amountToReceive,
            block.timestamp
        );

        bool isApproved =
            IERC20(underlyingAssetAddress).approve(
                treasuryPoolAddress,
                repaymentDetails.loanPrincipalToRepay.add(
                    repaymentDetails.payableInterest
                )
            );
        require(isApproved, "approve failed");

        ITreasuryPool(treasuryPoolAddress).repay(
            repaymentDetails.loanPrincipalToRepay,
            repaymentDetails.payableInterest
        );
        // _insuranceFund.transfer(repaymentDetails.taxAmount)
        IBtoken(btokenAddress).burn(msg.sender, amount);
        IERC20(underlyingAssetAddress).safeTransfer(
            msg.sender,
            repaymentDetails.amountToReceive
        );
    }

    function computeBorrowerInterestEarning()
        external
        override
        onlyBy(treasuryPoolAddress)
        returns (uint256 borrowerInterestEarning)
    {
        require(!paused(), "paused");

        (
            ,
            uint256[] memory poolIntegerInterestRates,
            IterableLoanMap.Loan[] memory poolSortedLoans
        ) = accrueInterestForLoan(_poolLoans);

        require(
            poolIntegerInterestRates.length == poolSortedLoans.length,
            "pool len diff"
        );

        uint256 interestEarning = getInterestEarning(poolSortedLoans);
        borrowerInterestEarning = interestEarning.sub(
            previousNettInterestEarning
        );
        previousNettInterestEarning = interestEarning;

        updateLoansForPool(poolIntegerInterestRates, poolSortedLoans);

        emit ComputeBorrowerInterestEarning(
            borrowerInterestEarning,
            block.timestamp
        );
    }

    function setGovernanceAccount(address newGovernanceAccount)
        external
        onlyBy(governanceAccount)
    {
        require(newGovernanceAccount != address(0), "0 governance account");

        governanceAccount = newGovernanceAccount;
    }

    function setTreasuryPoolAddress(address newTreasuryPoolAddress)
        external
        onlyBy(governanceAccount)
    {
        require(
            newTreasuryPoolAddress != address(0),
            "0 treasury pool address"
        );

        treasuryPoolAddress = newTreasuryPoolAddress;
    }

    function setAdapterAddress(address newAdapterAddress)
        external
        onlyBy(governanceAccount)
    {
        require(newAdapterAddress != address(0), "0 adapter address");

        adapterAddress = newAdapterAddress;
    }

    function pause() external onlyBy(governanceAccount) {
        _pause();
    }

    function unpause() external onlyBy(governanceAccount) {
        _unpause();
    }

    function sweep(address to) external override onlyBy(governanceAccount) {
        require(to != address(0), "zero to address");

        uint256 balance =
            IERC20(underlyingAssetAddress).balanceOf(address(this));
        // https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
        // slither-disable-next-line incorrect-equality
        if (balance == 0) {
            return;
        }

        emit Sweep(
            address(this),
            to,
            underlyingAssetAddress,
            balance,
            msg.sender
        );

        IERC20(underlyingAssetAddress).safeTransfer(to, balance);
    }

    function getTotalTransferToAdapterFor(address account)
        external
        view
        override
        returns (uint256 totalTransferToAdapter)
    {
        require(account != address(0), "zero account");

        totalTransferToAdapter = _totalTransferToAdapter[account];
    }

    function getLoansAtLastAccrualFor(address account)
        external
        view
        override
        returns (
            uint256[] memory interestRates,
            uint256[] memory principalsOnly,
            uint256[] memory principalsWithInterest,
            uint256[] memory lastAccrualTimestamps
        )
    {
        require(account != address(0), "zero account");

        uint256 numEntries = _farmerLoans[account].length();
        interestRates = new uint256[](numEntries);
        principalsOnly = new uint256[](numEntries);
        principalsWithInterest = new uint256[](numEntries);
        lastAccrualTimestamps = new uint256[](numEntries);

        for (uint256 i = 0; i < numEntries; i++) {
            (uint256 interestRate, IterableLoanMap.Loan memory farmerLoan) =
                _farmerLoans[account].at(i);

            interestRates[i] = interestRate;
            principalsOnly[i] = farmerLoan._principalOnly;
            principalsWithInterest[i] = farmerLoan._principalWithInterest;
            lastAccrualTimestamps[i] = farmerLoan._lastAccrualTimestamp;
        }
    }

    function getPoolLoansAtLastAccrual()
        external
        view
        override
        returns (
            uint256[] memory interestRates,
            uint256[] memory principalsOnly,
            uint256[] memory principalsWithInterest,
            uint256[] memory lastAccrualTimestamps
        )
    {
        uint256 numEntries = _poolLoans.length();
        interestRates = new uint256[](numEntries);
        principalsOnly = new uint256[](numEntries);
        principalsWithInterest = new uint256[](numEntries);
        lastAccrualTimestamps = new uint256[](numEntries);

        for (uint256 i = 0; i < numEntries; i++) {
            (uint256 interestRate, IterableLoanMap.Loan memory poolLoan) =
                _poolLoans.at(i);

            interestRates[i] = interestRate;
            principalsOnly[i] = poolLoan._principalOnly;
            principalsWithInterest[i] = poolLoan._principalWithInterest;
            lastAccrualTimestamps[i] = poolLoan._lastAccrualTimestamp;
        }
    }

    /**
     * @dev Returns the borrow nominal annual rate round down to nearest integer
     *
     * @param utilisationRate as percentage in unsigned 64.64-bit fixed point number
     * @return integerInterestRate as percentage round down to nearest integer
     */
    function getBorrowNominalAnnualRate(uint256 utilisationRate)
        public
        pure
        returns (uint256 integerInterestRate)
    {
        // https://github.com/crytic/slither/wiki/Detector-Documentation#too-many-digits
        // slither-disable-next-line too-many-digits
        require(utilisationRate <= 0x640000000000000000, "> 100%");

        if (utilisationRate <= UTILISATION_RATE_POINT_1) {
            integerInterestRate = INTEREST_RATE_INTEGER_POINT_1;
        } else if (utilisationRate < UTILISATION_RATE_POINT_2) {
            uint256 pointSlope =
                utilisationRate.sub(UTILISATION_RATE_POINT_1).mul(
                    INTEREST_RATE_SLOPE_1
                ) >> (NUM_FRACTION_BITS * 2);

            integerInterestRate = pointSlope.add(INTEREST_RATE_INTEGER_POINT_1);
        } else {
            uint256 pointSlope =
                utilisationRate.sub(UTILISATION_RATE_POINT_2).mul(
                    INTEREST_RATE_SLOPE_2
                ) >> (NUM_FRACTION_BITS * 2);

            integerInterestRate = pointSlope.add(INTEREST_RATE_INTEGER_POINT_2);
        }
    }

    /**
     * @dev Returns the accrue per second compound interest, reverts if overflow
     *
     * @param presentValue in wei
     * @param nominalAnnualRate as percentage in unsigned integer
     * @param numSeconds in unsigned integer
     * @return futureValue in unsigned 64.64-bit fixed point number
     */
    function accruePerSecondCompoundInterest(
        uint256 presentValue,
        uint256 nominalAnnualRate,
        uint256 numSeconds
    ) public pure returns (uint256 futureValue) {
        require(nominalAnnualRate <= 100, "> 100%");

        uint256 exponent =
            numSeconds.mul(
                (
                    ((
                        nominalAnnualRate.add(SECONDS_IN_YEAR.mul(PERCENT_100))
                    ) << NUM_FRACTION_BITS)
                        .div(SECONDS_IN_YEAR.mul(PERCENT_100))
                )
                    .logBase2()
            );

        futureValue =
            exponent.expBase2().mul(presentValue) >>
            NUM_FRACTION_BITS;
    }

    /**
     * @dev Returns the seconds since last accrual
     *
     * @param currentTimestamp in seconds
     * @param lastAccrualTimestamp in seconds
     * @return secondsSinceLastAccrual
     * @return accrualTimestamp in seconds
     */
    function getSecondsSinceLastAccrual(
        uint256 currentTimestamp,
        uint256 lastAccrualTimestamp
    )
        public
        pure
        returns (uint256 secondsSinceLastAccrual, uint256 accrualTimestamp)
    {
        require(
            currentTimestamp >= lastAccrualTimestamp,
            "current before last"
        );

        secondsSinceLastAccrual = currentTimestamp.sub(lastAccrualTimestamp);
        accrualTimestamp = currentTimestamp;
    }

    function accrueInterestForLoan(
        IterableLoanMap.RateToLoanMap storage rateToLoanMap
    )
        private
        view
        returns (
            uint256 outstandingInterest,
            uint256[] memory integerInterestRates,
            IterableLoanMap.Loan[] memory sortedLoans
        )
    {
        bool[] memory interestRateExists = new bool[](PERCENT_100 + 1);
        IterableLoanMap.Loan[] memory loansByInterestRate =
            new IterableLoanMap.Loan[](PERCENT_100 + 1);

        uint256 numEntries = rateToLoanMap.length();
        integerInterestRates = new uint256[](numEntries);
        sortedLoans = new IterableLoanMap.Loan[](numEntries);
        outstandingInterest = 0;

        for (uint256 i = 0; i < numEntries; i++) {
            (
                uint256 integerNominalAnnualRate,
                IterableLoanMap.Loan memory loan
            ) = rateToLoanMap.at(i);

            (uint256 secondsSinceLastAccrual, uint256 accrualTimestamp) =
                getSecondsSinceLastAccrual(
                    block.timestamp,
                    loan._lastAccrualTimestamp
                );

            loan._lastAccrualTimestamp = accrualTimestamp;

            if (
                loan._principalWithInterest > 0 && secondsSinceLastAccrual > 0
            ) {
                loan._principalWithInterest = accruePerSecondCompoundInterest(
                    loan._principalWithInterest,
                    integerNominalAnnualRate,
                    secondsSinceLastAccrual
                );
            }

            outstandingInterest = outstandingInterest
                .add(loan._principalWithInterest)
                .sub(loan._principalOnly);

            loansByInterestRate[integerNominalAnnualRate] = loan;
            interestRateExists[integerNominalAnnualRate] = true;
        }

        uint256 index = 0;
        for (
            uint256 rate = INTEREST_RATE_INTEGER_POINT_1;
            rate <= PERCENT_100;
            rate++
        ) {
            if (interestRateExists[rate]) {
                integerInterestRates[index] = rate;
                sortedLoans[index] = loansByInterestRate[rate];
                index++;
            }
        }
    }

    function accrueInterestBasedOnInterestRates(
        IterableLoanMap.RateToLoanMap storage rateToLoanMap,
        uint256[] memory inIntegerInterestRates
    )
        private
        view
        returns (
            uint256[] memory outIntegerInterestRates,
            IterableLoanMap.Loan[] memory outSortedLoans
        )
    {
        uint256 numEntries = inIntegerInterestRates.length;
        outIntegerInterestRates = new uint256[](numEntries);
        outSortedLoans = new IterableLoanMap.Loan[](numEntries);

        for (uint256 i = 0; i < numEntries; i++) {
            (bool keyExists, IterableLoanMap.Loan memory loan) =
                rateToLoanMap.tryGet(inIntegerInterestRates[i]);

            (uint256 secondsSinceLastAccrual, uint256 accrualTimestamp) =
                getSecondsSinceLastAccrual(
                    block.timestamp,
                    keyExists ? loan._lastAccrualTimestamp : block.timestamp
                );

            loan._lastAccrualTimestamp = accrualTimestamp;

            if (
                loan._principalWithInterest > 0 && secondsSinceLastAccrual > 0
            ) {
                loan._principalWithInterest = accruePerSecondCompoundInterest(
                    loan._principalWithInterest,
                    inIntegerInterestRates[i],
                    secondsSinceLastAccrual
                );
            }

            outIntegerInterestRates[i] = inIntegerInterestRates[i];
            outSortedLoans[i] = loan;
        }
    }

    function calculateRepaymentDetails(
        uint256 btokenAmount,
        uint256 underlyingAssetQuantity,
        uint256 outstandingInterest
    ) private view returns (RepaymentDetails memory repaymentDetails) {
        uint256 totalTransferToAdapter = _totalTransferToAdapter[msg.sender];
        // https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply
        // slither-disable-next-line divide-before-multiply
        uint256 underlyingAssetInvested =
            btokenAmount.mul(totalTransferToAdapter).div(
                IBtoken(btokenAddress).balanceOf(msg.sender)
            );

        uint256 profit = 0;
        repaymentDetails.taxAmount = 0;
        if (underlyingAssetQuantity > underlyingAssetInvested) {
            profit = underlyingAssetQuantity.sub(underlyingAssetInvested);
            repaymentDetails.taxAmount = profit.mul(taxRate).div(PERCENT_100);
        }

        uint256 principal = underlyingAssetInvested.div(leverageFactor);
        // slither-disable-next-line divide-before-multiply
        repaymentDetails.payableInterest = outstandingInterest
            .mul(underlyingAssetInvested)
            .div(totalTransferToAdapter);
        repaymentDetails.loanPrincipalToRepay = underlyingAssetInvested.sub(
            principal
        );
        repaymentDetails.amountToReceive = principal
            .add(profit)
            .sub(repaymentDetails.taxAmount)
            .sub(repaymentDetails.payableInterest);
    }

    function getInterestEarning(IterableLoanMap.Loan[] memory poolSortedLoans)
        private
        pure
        returns (uint256 interestEarning)
    {
        interestEarning = 0;
        for (uint256 index = 0; index < poolSortedLoans.length; index++) {
            interestEarning = interestEarning
                .add(poolSortedLoans[index]._principalWithInterest)
                .sub(poolSortedLoans[index]._principalOnly);
        }
    }

    function updateLoansForFarmerAndPool(
        uint256[] memory integerInterestRates,
        IterableLoanMap.Loan[] memory farmerSortedLoans,
        IterableLoanMap.Loan[] memory poolSortedLoans,
        RepaymentDetails memory repaymentDetails
    ) private {
        require(integerInterestRates.length > 0, "integerInterestRates len");
        require(
            farmerSortedLoans.length == integerInterestRates.length,
            "farmerSortedLoans len"
        );
        require(
            poolSortedLoans.length == integerInterestRates.length,
            "poolSortedLoans len"
        );

        uint256 repayPrincipalRemaining = repaymentDetails.loanPrincipalToRepay;
        uint256 repayPrincipalWithInterestRemaining =
            repaymentDetails.loanPrincipalToRepay.add(
                repaymentDetails.payableInterest
            );

        for (uint256 index = integerInterestRates.length; index > 0; index--) {
            if (repayPrincipalRemaining > 0) {
                if (
                    farmerSortedLoans[index - 1]._principalOnly >=
                    repayPrincipalRemaining
                ) {
                    farmerSortedLoans[index - 1]
                        ._principalOnly = farmerSortedLoans[index - 1]
                        ._principalOnly
                        .sub(repayPrincipalRemaining);

                    poolSortedLoans[index - 1]._principalOnly = poolSortedLoans[
                        index - 1
                    ]
                        ._principalOnly
                        .sub(repayPrincipalRemaining);

                    repayPrincipalRemaining = 0;
                } else {
                    poolSortedLoans[index - 1]._principalOnly = poolSortedLoans[
                        index - 1
                    ]
                        ._principalOnly
                        .sub(farmerSortedLoans[index - 1]._principalOnly);

                    repayPrincipalRemaining = repayPrincipalRemaining.sub(
                        farmerSortedLoans[index - 1]._principalOnly
                    );

                    farmerSortedLoans[index - 1]._principalOnly = 0;
                }
            }

            if (repayPrincipalWithInterestRemaining > 0) {
                if (
                    farmerSortedLoans[index - 1]._principalWithInterest >=
                    repayPrincipalWithInterestRemaining
                ) {
                    farmerSortedLoans[index - 1]
                        ._principalWithInterest = farmerSortedLoans[index - 1]
                        ._principalWithInterest
                        .sub(repayPrincipalWithInterestRemaining);

                    poolSortedLoans[index - 1]
                        ._principalWithInterest = poolSortedLoans[index - 1]
                        ._principalWithInterest
                        .sub(repayPrincipalWithInterestRemaining);

                    repayPrincipalWithInterestRemaining = 0;
                } else {
                    poolSortedLoans[index - 1]
                        ._principalWithInterest = poolSortedLoans[index - 1]
                        ._principalWithInterest
                        .sub(
                        farmerSortedLoans[index - 1]._principalWithInterest
                    );

                    repayPrincipalWithInterestRemaining = repayPrincipalWithInterestRemaining
                        .sub(
                        farmerSortedLoans[index - 1]._principalWithInterest
                    );

                    farmerSortedLoans[index - 1]._principalWithInterest = 0;
                }
            }

            if (
                farmerSortedLoans[index - 1]._principalOnly > 0 ||
                farmerSortedLoans[index - 1]._principalWithInterest > 0
            ) {
                // https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
                // slither-disable-next-line unused-return
                _farmerLoans[msg.sender].set(
                    integerInterestRates[index - 1],
                    farmerSortedLoans[index - 1]
                );
            } else {
                // slither-disable-next-line unused-return
                _farmerLoans[msg.sender].remove(
                    integerInterestRates[index - 1]
                );
            }

            if (
                poolSortedLoans[index - 1]._principalOnly > 0 ||
                poolSortedLoans[index - 1]._principalWithInterest > 0
            ) {
                // slither-disable-next-line unused-return
                _poolLoans.set(
                    integerInterestRates[index - 1],
                    poolSortedLoans[index - 1]
                );
            } else {
                // slither-disable-next-line unused-return
                _poolLoans.remove(integerInterestRates[index - 1]);
            }
        }
    }

    function updateLoansForPool(
        uint256[] memory integerInterestRates,
        IterableLoanMap.Loan[] memory poolSortedLoans
    ) private {
        require(
            poolSortedLoans.length == integerInterestRates.length,
            "poolSortedLoans len"
        );

        for (uint256 index = 0; index < integerInterestRates.length; index++) {
            if (
                poolSortedLoans[index]._principalOnly > 0 ||
                poolSortedLoans[index]._principalWithInterest > 0
            ) {
                // slither-disable-next-line unused-return
                _poolLoans.set(
                    integerInterestRates[index],
                    poolSortedLoans[index]
                );
            } else {
                // slither-disable-next-line unused-return
                _poolLoans.remove(integerInterestRates[index]);
            }
        }
    }
}