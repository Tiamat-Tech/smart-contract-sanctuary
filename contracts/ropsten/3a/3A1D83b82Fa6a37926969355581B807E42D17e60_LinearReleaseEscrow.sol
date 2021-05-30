// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @dev An escrow contract that allow beneficiaries to claim tokens during
 * and after an accrual period. During the accrual period the tokens are released
 * with a linear schedule, after the release time they can all be claimed.
 * After the rescue time, which is always after the release time, anybody can send
 * the residual unclaimed tokens to the rescue account, after this event the
 * beneficiaries can no longer claim their tokens. Any other token sent to
 * the smart contract can always be recovered at any time.
 */
contract LinearReleaseEscrow {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    struct UserPosition {
        // The sum of the amounts that the beneficiaries can claim
        uint256 totalAmount;
        // Amount actually already claimed by the beneficiaries
        uint256 claimedAmount;
    }

    /* ============ Storage and constants ============ */

    // The ERC20 basic token to be released
    IERC20 internal immutable _token;

    // Timestamp when beneficiaries can start to receive the held tokens
    uint256 internal immutable _startAccrualTime;

    // Timestamp when all tokens are released for all beneficiaries
    uint256 internal immutable _releaseTime;

    // Timestamp when the held token can be rescued
    uint256 internal immutable _rescueTime;

    // Address that will receive the rescued tokens, after the rescue time
    address internal immutable _rescuer;

    // User that has the ability to add new beneficiaries
    address internal immutable _manager;

    // Duration of accrual period, stored to save gas
    uint256 internal _accrualDuration;

    // Address of the token beneficiaries
    mapping(address => UserPosition) internal _beneficiaries;

    // Total residual amount to be claimed by all beneficiaries
    uint256 internal _totalResidualAmount;

    // If True the contract was already rescued
    bool internal _isRescued;

    /* ============ Modifiers ============ */

    modifier isNotRescued() {
        require(_isRescued == false, "Contract already rescued");
        _;
    }

    /* ============ Events ============ */

    event BeneficiaryAdded(
        address indexed beneficiary_,
        uint256 amount_,
        uint256 totalUsersAmount_
    );

    event TokenReleased(
        address indexed beneficiary_,
        uint256 amountWithdrawn_,
        uint256 residualBeneficiaryAmount_
    );

    event TokenRescued(uint256 amountRescued_);

    constructor(
        IERC20 token_,
        uint256 startAccrualTime_,
        uint256 releaseTime_,
        uint256 rescueTime_,
        address rescuer_,
        address manager_
    ) {
        // solhint-disable-next-line not-rely-on-time
        require(
            startAccrualTime_ > block.timestamp,
            "Start accrual time is not after current time"
        );
        // solhint-disable-next-line not-rely-on-time
        require(
            releaseTime_ > startAccrualTime_,
            "Release time is not after start accrual time"
        );
        // solhint-disable-next-line not-rely-on-time
        require(
            rescueTime_ > releaseTime_,
            "Rescue time is not after release time"
        );
        require(rescuer_ != address(0), "Rescuer adresses cannot be 0 address");
        require(manager_ != address(0), "Manager adresses cannot be 0 address");
        _token = token_;
        _rescuer = rescuer_;
        _startAccrualTime = startAccrualTime_;
        _releaseTime = releaseTime_;
        _rescueTime = rescueTime_;
        _manager = manager_;
        _accrualDuration = releaseTime_.sub(startAccrualTime_);
    }

    /* ============ External functions ============ */

    /**
     * @notice Manager, before starting accrual date, can add new beneficiaries
     * and their corresponding amounts.
     */
    function addBeneficiaries(
        address[] calldata beneficiaries_,
        uint256[] calldata amounts_
    ) external virtual {
        require(msg.sender == _manager, "Sender must be the manager");
        require(
            block.timestamp < _startAccrualTime,
            "Cannot add beneficiaries before the start-accrual time"
        );
        require(beneficiaries_.length > 0, "No beneficiary passed");
        require(
            beneficiaries_.length == amounts_.length,
            "Different number of beneficiaries and amounts"
        );
        uint256 newTotalAmount = _totalResidualAmount;
        for (uint256 j = 0; j < beneficiaries_.length; j++) {
            address newBeneficiary = beneficiaries_[j];
            uint256 newAmount = amounts_[j];
            require(
                _beneficiaries[newBeneficiary].totalAmount == 0,
                "Beneficiary was already added"
            );
            require(
                newBeneficiary != address(0),
                "Beneficiary can not be zero address"
            );
            require(newAmount != 0, "Beneficiary amount cannot be 0");
            _beneficiaries[newBeneficiary] = UserPosition(newAmount, 0);
            newTotalAmount = newTotalAmount.add(newAmount);

            emit BeneficiaryAdded(newBeneficiary, newAmount, newTotalAmount);
        }

        require(
            newTotalAmount <= _token.balanceOf(address(this)),
            "Contract tokens are not enough to cover users rewards"
        );
        _totalResidualAmount = newTotalAmount;
    }

    /**
     * @notice Transfers the supported token to the sender (a beneficiary),
     * during the accrual period in linear proportion to the elapsed time,
     * or the total residual amount after the release time.
     */
    function release()
        external
        virtual
        isNotRescued
        returns (uint256 amountWithdrawn_, uint256 residualAmount_)
    {
        // solhint-disable-next-line not-rely-on-time
        require(
            block.timestamp >= _startAccrualTime,
            "Current time is before release time"
        );
        uint256 beneficiaryTotalAmount = _beneficiaries[msg.sender].totalAmount;
        require(
            beneficiaryTotalAmount != 0 &&
                beneficiaryTotalAmount !=
                _beneficiaries[msg.sender].claimedAmount,
            "Sender is not a beneficiary or tokens are already claimed"
        );

        (amountWithdrawn_, residualAmount_) = releaseAmount(msg.sender);

        _token.safeTransfer(msg.sender, amountWithdrawn_);
        emit TokenReleased(msg.sender, amountWithdrawn_, residualAmount_);
    }

    /**
     * @notice returns amount withdrawn and residual amount. If the block time stamp is less than release time
     * accuralClaimCalculation is called, else totaClaimCalculation is called
     */
    function releaseAmount(address _address)
        internal
        returns (uint256 amountWithdrawn_, uint256 residualAmount_)
    {
        if (block.timestamp < _releaseTime) {
            (amountWithdrawn_, residualAmount_) = _accrualClaimCalculation(
                _address
            );
        } else {
            (amountWithdrawn_, residualAmount_) = _totalClaimCalculation(
                _address
            );
        }
    }

    /**
     * @notice Transfer, after the rescue time, the supported token residual amount
     * of all beneficiaries, to the rescuer. Also sets the state to rescued, so that
     * no more releases are possible.
     */
    function rescue() external virtual isNotRescued returns (uint256 amount_) {
        // solhint-disable-next-line not-rely-on-time
        require(
            block.timestamp >= _rescueTime,
            "Current time is before rescue time"
        );
        amount_ = _totalResidualAmount;
        require(amount_ > 0, "No residual tokens to rescue");
        _totalResidualAmount = 0;
        _isRescued = true;
        _token.safeTransfer(_rescuer, amount_);
        emit TokenRescued(amount_);
    }

    /**
     * @notice Recovers unsupported tokens to the rescuer or excess amount
     * of supported token.
     */
    function recovery(IERC20 token_)
        external
        virtual
        returns (uint256 amount_)
    {
        if (_token == token_) {
            amount_ = token_.balanceOf(address(this)).sub(_totalResidualAmount);
        } else {
            amount_ = token_.balanceOf(address(this));
        }
        require(amount_ > 0, "No tokens to recover");
        token_.safeTransfer(_rescuer, amount_);
    }

    /* ============ Internal functions ============ */

    /**
     * @notice Calculate, during accrual period, the amount that a beneficiary withdraw
     * and the residual one.
     */
    function _accrualClaimCalculation(address beneficiary_)
        internal
        returns (uint256 amountWithdrawn_, uint256 residualAmount_)
    {
        uint256 timePassed = block.timestamp.sub(_startAccrualTime);
        uint256 totalTokens = _beneficiaries[beneficiary_].totalAmount;
        uint256 claimedTokens = _beneficiaries[beneficiary_].claimedAmount;
        amountWithdrawn_ = totalTokens
            .mul(timePassed)
            .div(_accrualDuration)
            .sub(claimedTokens);
        uint256 newClaimedAmount = claimedTokens.add(amountWithdrawn_);
        _beneficiaries[beneficiary_].claimedAmount = newClaimedAmount;
        residualAmount_ = totalTokens.sub(newClaimedAmount);
        _totalResidualAmount = _totalResidualAmount.sub(amountWithdrawn_);
    }

    /**
     * @notice Calculate, after accrual period, the amount that a beneficiary withdraw
     * and the residual one.
     */
    function _totalClaimCalculation(address beneficiary_)
        internal
        returns (uint256 amountWithdrawn_, uint256 residualAmount_)
    {
        uint256 totalTokens = _beneficiaries[beneficiary_].totalAmount;
        uint256 claimedTokens = _beneficiaries[beneficiary_].claimedAmount;
        amountWithdrawn_ = totalTokens.sub(claimedTokens);
        _beneficiaries[beneficiary_].claimedAmount = totalTokens;
        residualAmount_ = 0;
        _totalResidualAmount = _totalResidualAmount.sub(amountWithdrawn_);
    }

    /**
     * @return The token being held for the beneficiaries.
     */
    function token() external view returns (IERC20) {
        return _token;
    }

    /**
     * @return The time when the accrual period starts.
     */
    function startAccrualTime() external view returns (uint256) {
        return _startAccrualTime;
    }

    /**
     * @return The time after which the tokens can be released.
     */
    function releaseTime() external view returns (uint256) {
        return _releaseTime;
    }

    /**
     * @return The rescue time.
     */
    function rescueTime() external view returns (uint256) {
        return _rescueTime;
    }

    /**
     * @return totalAmount_ and claimedAmount_
     */
    function beneficiary(address beneficiary_)
        external
        view
        returns (uint256 totalAmount_, uint256 claimedAmount_)
    {
        totalAmount_ = _beneficiaries[beneficiary_].totalAmount;
        require(totalAmount_ > 0, "Beneficiary has zero balance");
        claimedAmount_ = _beneficiaries[beneficiary_].claimedAmount;
    }

    /**
     * @return The token rescuer.
     */
    function rescuer() external view returns (address) {
        return _rescuer;
    }

    /**
     * @return The contract manager.
     */
    function manager() external view returns (address) {
        return _manager;
    }

    /**
     * @return The total amount currently claimable
     */
    function totalResidualAmount() external view returns (uint256) {
        return _totalResidualAmount;
    }

    /**
     * @return The current balance of the supported token.
     */
    function balance() external view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @return The accrual-period duration.
     */
    function accrualDuration() external view returns (uint256) {
        return _accrualDuration;
    }

    /**
     * @return True if the contract has been rescued, otherwise false
     */
    function isRescued() external view returns (bool) {
        return _isRescued;
    }
}