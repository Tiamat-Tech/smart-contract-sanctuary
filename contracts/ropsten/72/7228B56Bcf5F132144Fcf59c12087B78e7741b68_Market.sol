// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./TNFT.sol";

contract Market is ERC20, Ownable, IERC721Receiver, Pausable {
    /**
     * @notice Whether or not new loans are being issued, rollovers allowed
     */
    bool private newActivityAllowed;

    /**
     * @notice NFT Collection Identifier for this market
     */
    address private collectionAddress;

    /**
     * @notice Address of TangeloController
     */
    address private controllerAddress;

    /**
     * @notice Address of TNFT Contract
     */
    address private tnftAddress;

    /**
     * @notice Total amount of outstanding borrows in this market
     */
    uint256 private totalBorrows;

    /**
     * @notice Total amount of reserves in this market
     */
    uint256 private totalReserves;

    /**
     * @notice Initial exchange rate used when minting the first Market Tokens (used when totalSupply = 0)
     */
    uint256 private initialExchangeRateMantissa = 0.2 * 1e28; //todo: decide value

    /**
     * @notice Fraction of interest currently set aside for reserves
     */
    uint64 private reserveFactorMantissa = 1 * 1e17; // 0.1

    /**
     * @notice Term length associated with loans in this market.
     */
    uint48 private termLengthDays = 90;

    /**
     * @notice Internal variable to track interest accumulated, and control when to release in the market.
     */
    uint256 private interestWithheld = 0;

    ////////////Interest Model Params
    /**
     * @notice The utilization point at which the jump multiplier is applied
     */
    uint256 private kink = 80 * 1e16; //80%
    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint256 private multiplierPerBlock = (4 * 1e16) / uint256(2102400); //4%
    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint256 private baseRatePerBlock = (8 * 1e16) / uint256(2102400); //8%
    /**
     * @notice The multiplierPerBlock after hitting a specified utilization point
     */
    uint256 private jumpMultiplierPerBlock = (150 * 1e16) / uint256(2102400); //150%

    //////////Lend-value model params
    /**
     * @notice The base lend value which is the y-intercept when utilization rate is 1
     */
    uint256 private baseLendValue = 0 ether;

    /**
     * @notice The multiplier of (1-utilization) rate that gives the slope of the lend value
     */
    uint256 private lendMultiple = 0 * 1e16; //0%

    /**
     * @notice Lend value hard ceiling. Should be around 80-90% floor price.
     */
    uint256 private maxLendValue = 100 ether;

    /**
     * @notice Event emitted when LP deposits ETH
     */
    event LiquidityAdded(address indexed _user, uint256 ethAmount);

    /**
     * @notice Event emitted when LP withdraws ETH
     */
    event LiquidityRemoved(address indexed _user, uint256 ethAmount);

    /**
     * @notice Event emitted when user takes a new loan
     */
    event LoanTaken(address indexed _user, uint256 tnftId, uint256 ethAmount);

    /**
     * @notice Event emitted when user repays and closes a loan
     */
    event LoanRepaid(address indexed _user, uint256 tnftId, uint256 ethAmount);

    /**
     * @notice Event emitted when user rollsover an existing loan
     */
    event LoanRollover(
        address indexed _user,
        uint256 tnftId,
        uint256 ethAmount
    );

    /**
     * @notice Event emitted when an overdue loan is foreclosed
     */
    event LoanForeclosed(
        address indexed _receiver,
        uint256 tnftId,
        uint256 foreclosureAmount
    );

    /**
     * @notice Event emitted when withheld interest is released
     */
    event InterestReleased();

    constructor(
        address _collectionAddress,
        address _controllerAddress,
        address _tnftAddress,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        collectionAddress = _collectionAddress;
        controllerAddress = _controllerAddress;
        tnftAddress = _tnftAddress;
    }

    /**
     * @notice Getter function for newActivityAllowed.
     */
    function isNewActivityAllowed() public view returns (bool) {
        return newActivityAllowed;
    }

    /**
     * @notice Setter function for newActivityAllowed.
     */
    function _setNewActivityAllowed(bool _newVal) external onlyOwner {
        newActivityAllowed = _newVal;
    }

    /**
     * @notice Getter function for termLengthDays
     */
    function getTermLengthDays() public view returns (uint48) {
        return termLengthDays;
    }

    /**
     * @notice Setter function for termLengthDays
     */
    function _setTermLengthDays(uint48 _newVal) external onlyOwner {
        termLengthDays = _newVal;
    }

    /**
     * @notice Getter function for reserveFactorMantissa
     */
    function getReserveFactorMantissa() public view returns (uint64) {
        return reserveFactorMantissa;
    }

    /**
     * @notice Setter function for reserveFactorMantissa
     */
    function _setReserveFactorMantissa(uint64 _newVal) external onlyOwner {
        reserveFactorMantissa = _newVal;
    }

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying owned by this contract
     */
    function getCashPrior() internal view returns (uint256) {
        return address(this).balance - msg.value;
    }

    /**
     * @notice Gets total assets owned by the market contract.
     * @return The quantity of assets on book + current value of loans
     */
    function getAssets() public view returns (uint256) {
        return address(this).balance + totalBorrows;
    }

    /**
     * @notice Setter function for baseLendValue
     */
    function _setBaseLendValue(uint256 _newVal) external onlyOwner {
        baseLendValue = _newVal;
    }

    /**
     * @notice Setter function for lendMultiple
     */
    function _setLendMultiple(uint256 _newVal) external onlyOwner {
        lendMultiple = _newVal;
    }

    /**
     * @notice Setter function for maxLendValue
     */
    function _setMaxLendValue(uint256 _newVal) external onlyOwner {
        maxLendValue = _newVal;
    }

    /**
     * @notice Function that takes an NFT as collateral, issues a loan and mints a TNFT
     * @param requestedLoanAmount loan amount requested
     * @param collectionTokenId tokenId of the NFT being used as collateral
     */
    function takeLoan(uint256 requestedLoanAmount, uint256 collectionTokenId)
        public
        whenNotPaused
    {
        require(isNewActivityAllowed(), "Market is not issuing new loans");
        require(
            requestedLoanAmount <= getCurrentLendValue(),
            "Too large loan requested"
        );
        require(requestedLoanAmount <= getUsableCash(), "Not enough liquidity");
        TNFT debtNft = TNFT(tnftAddress);
        IERC721 collateralNft = IERC721(collectionAddress);
        collateralNft.safeTransferFrom(
            msg.sender,
            address(this),
            collectionTokenId
        );
        uint256 interestAmount = getInterestDue(
            requestedLoanAmount,
            termLengthDays
        );
        debtNft.mint(
            msg.sender,
            collectionAddress,
            collectionTokenId,
            requestedLoanAmount,
            interestAmount,
            termLengthDays
        );
        totalBorrows += requestedLoanAmount;
        payable(msg.sender).transfer(requestedLoanAmount);
        //todo: fix to debt token id
        emit LoanTaken(msg.sender, collectionTokenId, requestedLoanAmount);
    }

    /**
     * @notice Function to repay loan, get back NFT, burn TNFT (debt position NFT)
     * @param tnftId Token ID of TNFT
     */
    function repayLoan(uint256 tnftId) public payable whenNotPaused {
        TNFT debtNft = TNFT(tnftAddress);
        require(debtNft.ownerOf(tnftId) == msg.sender, "Must be owner");
        require(
            collectionAddress == debtNft.getCollectionAddress(tnftId),
            "Incorrect Market"
        );
        require(
            msg.value >= debtNft.getBalanceDue(tnftId),
            "Must pay back debt"
        );
        uint256 interestCollected = msg.value - debtNft.getPrincipal(tnftId);
        uint256 reserveContribution = ((interestCollected *
            reserveFactorMantissa) / 1e18);
        debtNft.burn(tnftId);
        totalReserves += reserveContribution;
        interestWithheld += (interestCollected - reserveContribution);
        IERC721 collateralNft = IERC721(debtNft.getCollectionAddress(tnftId));
        totalBorrows -= debtNft.getPrincipal(tnftId);
        // return NFT
        collateralNft.safeTransferFrom(
            address(this),
            msg.sender,
            debtNft.getCollectionTokenId(tnftId)
        );
        emit LoanRepaid(msg.sender, tnftId, msg.value);
    }

    /**
     @notice This function must be implemented like so to confirm this contract can receive NFT tokens
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    /**
     * @notice ERC-20 override for decimals representation of Market tokens.
     */
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    /**
     * @notice Allows user to rollover an existing loan
     * @param tnftId TNFT Id of loan
     * @param requestedLoanAmount new amount to borrow after rollover
     */
    function rollover(uint256 tnftId, uint256 requestedLoanAmount)
        public
        payable
        whenNotPaused
    {
        require(isNewActivityAllowed(), "Market is not issuing new loans");
        require(requestedLoanAmount <= getCurrentLendValue(), "Loan too large");
        TNFT debtNft = TNFT(tnftAddress);
        require(debtNft.ownerOf(tnftId) == msg.sender, "Invalid owner");

        uint256 principal = debtNft.getPrincipal(tnftId);
        uint256 interest = debtNft.getFee(tnftId);

        if (requestedLoanAmount <= principal) {
            require(
                msg.value >= (principal - requestedLoanAmount + interest),
                "Not enough"
            );
            debtNft.burn(tnftId);
            totalBorrows -= (principal - requestedLoanAmount);
        } else {
            uint256 refundNeeded = requestedLoanAmount - principal;
            if (refundNeeded <= interest) {
                require(msg.value >= (interest - refundNeeded), "Not enough");
                debtNft.burn(tnftId);
            } else {
                require(
                    (refundNeeded - interest) <= getUsableCash(),
                    "Not enough liquidity"
                );
                debtNft.burn(tnftId);
                payable(msg.sender).transfer(refundNeeded - interest);
            }
            totalBorrows += (requestedLoanAmount - principal);
        }

        uint256 reserveContribution = ((interest * reserveFactorMantissa) /
            1e18);
        totalReserves += reserveContribution;
        interestWithheld += (interest - reserveContribution);

        debtNft.mint(
            msg.sender,
            collectionAddress,
            debtNft.getCollectionTokenId(tnftId),
            requestedLoanAmount,
            getInterestDue(requestedLoanAmount, termLengthDays),
            termLengthDays
        );
        emit LoanRollover(msg.sender, tnftId, requestedLoanAmount);
    }

    /**
     * @notice function to deposit ETH in the contract and mint LP Tokens
     */
    function addLiquidity() public payable whenNotPaused {
        uint256 tokenCount = (msg.value * 1e18) / getCurrentExchangeRate();
        _mint(msg.sender, tokenCount);
        emit LiquidityAdded(msg.sender, msg.value);
    }

    /**
     * @notice Sender redeems LP Tokens in exchange for ETH
     * @param tTokenAmount the number of LP Tokens to redeem in exchange for ETH
     */
    function removeLiquidity(uint256 tTokenAmount) public whenNotPaused {
        uint256 ethAmount = (tTokenAmount * getCurrentExchangeRate()) / 1e18;
        require(balanceOf(msg.sender) >= tTokenAmount, "Insufficient balance");
        require(ethAmount <= getUsableCash(), "Insufficient liquidity");
        _burn(msg.sender, tTokenAmount);
        payable(msg.sender).transfer(ethAmount);
        emit LiquidityRemoved(msg.sender, ethAmount);
    }

    /**
     * @notice Reduces reserves by transferring to admin
     * @param amount Amount of reduction to reserves
     */
    function _withdrawContractRevenue(uint256 amount) external onlyOwner {
        require(amount <= totalReserves, "Insufficient liquidity");
        totalReserves -= amount;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @notice Calculates the exchange rate from ETH to Market LP Tokens
     * @return current ETH/LP token exchange rate (scaled by 1e18)
     */
    function getCurrentExchangeRate() public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        return
            _totalSupply != 0
                ? (((getUsableCash() + totalBorrows) * 1e18) / _totalSupply)
                : initialExchangeRateMantissa;
    }

    /**
     * @notice Helper method to get account token balance of sender
     */
    function getAccountBalance() external view returns (uint256) {
        return balanceOf(msg.sender);
    }

    /**
     * @notice Function to manually reset interest rate model params
     * @param baseRatePerYearPct The base interest rate which is the y-intercept when utilization rate is 0. Denoted as % (0-100)
     * @param multiplierPerYearPct The multiplier of utilization rate that gives the slope of the interest rate. Denoted as % (0-100)
     * @param jumpMultiplierPerYearPct The multiplierPerBlock after hitting a specified utilization point. Denoted as % (0-100).
     * @param kinkPct_ The utilization point at which the jump multiplier is applied. Denoted as % (0-100).
     */
    function _setInterestRateParams(
        uint256 baseRatePerYearPct,
        uint256 multiplierPerYearPct,
        uint256 jumpMultiplierPerYearPct,
        uint256 kinkPct_
    ) external onlyOwner {
        // uint24 blocksPerYear = 2102400;
        multiplierPerBlock = (multiplierPerYearPct * 1e16) / uint256(2102400);
        baseRatePerBlock = (baseRatePerYearPct * 1e16) / uint256(2102400);
        jumpMultiplierPerBlock =
            (jumpMultiplierPerYearPct * 1e16) /
            uint256(2102400);
        kink = kinkPct_ * 1e16;
    }

    /**
     * @notice calculates the cash available to use for lending, withdrawal
     * @return usable cash value
     */
    function getUsableCash() internal view returns (uint256) {
        return (getCashPrior() - totalReserves - interestWithheld);
    }

    /**
     * @notice Function to reset interest withheld; gets counted within totalCash for internal accounting.
     */
    function _releaseWithheldInterest() external onlyOwner {
        interestWithheld = 0;
        emit InterestReleased();
    }

    /**
     * @notice Calculates current lend value from a linear curve based on current utilization
     * @return Current lend value for any loan being originated in the market
     */

    function getCurrentLendValue() public view returns (uint256) {
        uint256 totalCash = getCashPrior();
        uint256 oneMinusUtilization = 1e18 -
            utilizationRate(totalCash, totalBorrows, totalReserves);
        uint256 lendVal = baseLendValue +
            ((oneMinusUtilization * lendMultiple) / 1e18);
        return lendVal <= maxLendValue ? lendVal : maxLendValue;
    }

    /**
     * @notice Calculates the total interest due for a given loan params
     * @param _principal principal of loan for which interest is being calculated
     * @param _termLengthDays duration of loan (in days) for which interest is being calculated
     * @return Absolute interest amount for loan
     */
    function getInterestDue(uint256 _principal, uint256 _termLengthDays)
        internal
        view
        returns (uint256)
    {
        uint256 totalCash = getCashPrior();
        uint256 borrowRatePerBlock = getBorrowRatePerBlock(
            totalCash,
            totalBorrows,
            totalReserves
        );
        // 5760 = 2102400/365; 2102400 = number of blocks per yr
        uint256 interestAmount = (_principal *
            _termLengthDays *
            borrowRatePerBlock *
            5760) / 1e18;
        return interestAmount;
    }

    /**
     * @notice Calculates the current borrow interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @return The borrow rate per block (as a percentage, and scaled by 1e18)
     */
    function getBorrowRatePerBlock(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view returns (uint256) {
        uint256 util = utilizationRate(cash, borrows, reserves);
        if (util <= kink) {
            return baseRatePerBlock + ((util * multiplierPerBlock) / 1e18);
        }
        uint256 normalRate = baseRatePerBlock +
            (kink * multiplierPerBlock) /
            1e18;
        uint256 excessUtil = util - kink;
        return normalRate + ((excessUtil * jumpMultiplierPerBlock) / 1e18);
    }

    /**
     * @notice Calculates the current supply interest rate per block
     * @param cash The total amount of cash the market has
     * @param borrows The total amount of borrows the market has outstanding
     * @param reserves The total amount of reserves the market has
     * @return The supply rate per block (as a percentage, and scaled by 1e18)
     */
    function getSupplyRatePerBlock(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public view returns (uint256) {
        uint256 oneMinusReserveFactor = 1e18 - reserveFactorMantissa;
        uint256 borrowRate = getBorrowRatePerBlock(cash, borrows, reserves);
        uint256 rateToPool = (borrowRate * oneMinusReserveFactor) / 1e18;
        return (utilizationRate(cash, borrows, reserves) * rateToPool) / 1e18;
    }

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, 1e18]
     */
    function utilizationRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves
    ) public pure returns (uint256) {
        return (borrows * 1e18) / (cash + borrows - reserves);
    }

    /**
     * @notice Admin function to pause all activity on contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Admin function to unpause all activity on contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Allows an external caller to foreclose an eligible loan
     * @param tnftId Token ID of TNFT
     */
    function foreclose(uint256 tnftId) external payable whenNotPaused {
        TNFT debtNft = TNFT(tnftAddress);
        require(
            msg.value >= debtNft.getLiveAuctionPrice(tnftId),
            "Insufficient bid val"
        );
        IERC721 collateralNft = IERC721(debtNft.getCollectionAddress(tnftId));
        uint256 collectionTokenId = debtNft.getCollectionTokenId(tnftId);
        uint256 principalAmount = debtNft.getPrincipal(tnftId);
        // Only contribute to reserves if foreclosure yields a profit for LP Pool.
        if (msg.value > principalAmount) {
            uint256 reserveContribution = (((msg.value -
                debtNft.getPrincipal(tnftId)) * reserveFactorMantissa) / 1e18);
            totalReserves += reserveContribution;
        }
        totalBorrows -= principalAmount;
        debtNft.burn(tnftId);
        collateralNft.safeTransferFrom(
            address(this),
            msg.sender,
            collectionTokenId
        );
        emit LoanForeclosed(msg.sender, tnftId, msg.value);
    }

    /**
     * @notice Receive Function
     */
    receive() external payable {
        totalReserves += msg.value;
    }

    /**
     * @notice Fallback Function
     */
    fallback() external payable {
        totalReserves += msg.value;
    }
}