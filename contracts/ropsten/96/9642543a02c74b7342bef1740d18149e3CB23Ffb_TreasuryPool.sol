// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ILfi.sol";
import "./interfaces/ILtoken.sol";
import "./interfaces/IDsecDistribution.sol";
import "./interfaces/IFarmingPool.sol";
import "./interfaces/ITreasuryPool.sol";

contract TreasuryPool is Pausable, ReentrancyGuard, ITreasuryPool {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public immutable lpRewardPerEpoch;
    uint256 public immutable teamRewardPerEpoch;
    address public immutable teamAccount;

    address public governanceAccount;
    address public farmingPoolAccount = address(0);
    address public lfiAddress;
    address public underlyingAssetAddress;
    address public ltokenAddress;
    address public dsecDistributionAddress;

    uint256 public totalUnderlyingAssetAmount = 0;
    uint256 public totalLoanedUnderlyingAssetAmount = 0;
    uint256 public totalLtokenAmount = 0;

    ILfi private _lfi;
    IERC20 private _underlyingAsset;
    ILtoken private _ltoken;
    IDsecDistribution private _dsecDistribution;

    constructor(
        address lfiAddress_,
        address underlyingAssetAddress_,
        address ltokenAddress_,
        address dsecDistributionAddress_,
        uint256 lpRewardPerEpoch_,
        uint256 teamRewardPerEpoch_,
        address teamAccount_
    ) {
        require(
            lfiAddress_ != address(0),
            "TreasuryPool: LFI address is the zero address"
        );
        require(
            underlyingAssetAddress_ != address(0),
            "TreasuryPool: underlying asset address is the zero address"
        );
        require(
            ltokenAddress_ != address(0),
            "TreasuryPool: LToken address is the zero address"
        );
        require(
            dsecDistributionAddress_ != address(0),
            "TreasuryPool: dsec distribution address is the zero address"
        );
        require(
            teamAccount_ != address(0),
            "TreasuryPool: team account is the zero address"
        );

        governanceAccount = msg.sender;
        lfiAddress = lfiAddress_;
        underlyingAssetAddress = underlyingAssetAddress_;
        ltokenAddress = ltokenAddress_;
        dsecDistributionAddress = dsecDistributionAddress_;
        lpRewardPerEpoch = lpRewardPerEpoch_;
        teamRewardPerEpoch = teamRewardPerEpoch_;
        teamAccount = teamAccount_;

        _lfi = ILfi(lfiAddress);
        _underlyingAsset = IERC20(underlyingAssetAddress);
        _ltoken = ILtoken(ltokenAddress);
        _dsecDistribution = IDsecDistribution(dsecDistributionAddress);
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "TreasuryPool: sender not authorized");
        _;
    }

    function addLiquidity(uint256 amount) external override nonReentrant {
        require(amount != 0, "TreasuryPool: can't add 0");
        require(!paused(), "TreasuryPool: deposit while paused");

        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-1
        // slither-disable-next-line reentrancy-no-eth
        uint256 lpLtokenAmount =
            farmingPoolAccount != address(0)
                ? _divExchangeRate(amount)
                : amount;

        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.add(amount);
        totalLtokenAmount = totalLtokenAmount.add(amount);

        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
        // slither-disable-next-line reentrancy-events
        emit AddLiquidity(
            msg.sender,
            underlyingAssetAddress,
            ltokenAddress,
            amount,
            lpLtokenAmount,
            block.timestamp
        );

        _underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
        _dsecDistribution.addDsec(msg.sender, amount);
        _ltoken.mint(msg.sender, lpLtokenAmount);
    }

    function removeLiquidity(uint256 amount) external override nonReentrant {
        require(amount != 0, "TreasuryPool: can't remove 0");
        require(!paused(), "TreasuryPool: withdraw while paused");
        require(
            getTotalUnderlyingAssetAvailableCore() > 0,
            "TreasuryPool: insufficient liquidity"
        );
        require(
            _ltoken.balanceOf(msg.sender) >= amount,
            "TreasuryPool: insufficient LToken"
        );

        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-1
        // slither-disable-next-line reentrancy-no-eth
        uint256 lpUnderlyingAssetAmount =
            farmingPoolAccount != address(0)
                ? _mulExchangeRate(amount)
                : amount;
        require(
            getTotalUnderlyingAssetAvailableCore() >= lpUnderlyingAssetAmount,
            "TreasuryPool: insufficient liquidity"
        );

        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.sub(
            lpUnderlyingAssetAmount
        );
        totalLtokenAmount = totalLtokenAmount.sub(amount);

        // https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
        // slither-disable-next-line reentrancy-events
        emit RemoveLiquidity(
            msg.sender,
            ltokenAddress,
            underlyingAssetAddress,
            amount,
            lpUnderlyingAssetAmount,
            block.timestamp
        );

        _ltoken.burn(msg.sender, amount);
        _dsecDistribution.removeDsec(msg.sender, amount);
        _underlyingAsset.safeTransfer(msg.sender, lpUnderlyingAssetAmount);
    }

    function redeemProviderReward(uint256 fromEpoch, uint256 toEpoch)
        external
        override
    {
        require(fromEpoch <= toEpoch, "TreasuryPool: invalid epoch range");
        require(!paused(), "TreasuryPool: redeem while paused");

        uint256 totalRewardAmount = 0;
        for (uint256 i = fromEpoch; i <= toEpoch; i++) {
            // https://github.com/crytic/slither/wiki/Detector-Documentation#calls-inside-a-loop
            // slither-disable-next-line calls-loop
            if (_dsecDistribution.hasRedeemedDsec(msg.sender, i)) {
                break;
            }

            // https://github.com/crytic/slither/wiki/Detector-Documentation#calls-inside-a-loop
            // slither-disable-next-line calls-loop
            uint256 rewardAmount =
                _dsecDistribution.redeemDsec(msg.sender, i, lpRewardPerEpoch);
            totalRewardAmount = totalRewardAmount.add(rewardAmount);
        }

        if (totalRewardAmount == 0) {
            return;
        }

        emit RedeemProviderReward(
            msg.sender,
            fromEpoch,
            toEpoch,
            lfiAddress,
            totalRewardAmount,
            block.timestamp
        );

        _lfi.mint(msg.sender, totalRewardAmount);
    }

    function redeemTeamReward(uint256 fromEpoch, uint256 toEpoch)
        external
        override
        onlyBy(teamAccount)
    {
        require(fromEpoch <= toEpoch, "TreasuryPool: invalid epoch range");
        require(!paused(), "TreasuryPool: redeem while paused");

        uint256 totalRewardAmount = 0;
        for (uint256 i = fromEpoch; i <= toEpoch; i++) {
            // https://github.com/crytic/slither/wiki/Detector-Documentation#calls-inside-a-loop
            // slither-disable-next-line calls-loop
            if (_dsecDistribution.hasRedeemedTeamReward(i)) {
                break;
            }

            // https://github.com/crytic/slither/wiki/Detector-Documentation#calls-inside-a-loop
            // slither-disable-next-line calls-loop
            _dsecDistribution.redeemTeamReward(i);
            totalRewardAmount = totalRewardAmount.add(teamRewardPerEpoch);
        }

        if (totalRewardAmount == 0) {
            return;
        }

        emit RedeemTeamReward(
            teamAccount,
            fromEpoch,
            toEpoch,
            lfiAddress,
            totalRewardAmount,
            block.timestamp
        );

        _lfi.mint(teamAccount, totalRewardAmount);
    }

    function loan(uint256 amount) external override onlyBy(farmingPoolAccount) {
        require(
            amount <= getTotalUnderlyingAssetAvailableCore(),
            "TreasuryPool: insufficient liquidity"
        );

        totalLoanedUnderlyingAssetAmount = totalLoanedUnderlyingAssetAmount.add(
            amount
        );

        emit Loan(amount, msg.sender, block.timestamp);

        _underlyingAsset.safeTransfer(msg.sender, amount);
    }

    function repay(uint256 principal, uint256 interest)
        external
        override
        onlyBy(farmingPoolAccount)
    {
        require(
            principal <= totalLoanedUnderlyingAssetAmount,
            "TreasuryPool: invalid amount"
        );

        uint256 totalAmount = principal.add(interest);
        totalLoanedUnderlyingAssetAmount = totalLoanedUnderlyingAssetAmount.sub(
            principal
        );
        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.add(interest);

        emit Repay(principal, interest, msg.sender, block.timestamp);

        _underlyingAsset.safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
    }

    /**
     * @return The utilisation rate, it represents as percentage in 64.64-bit fixed
     *         point number e.g. 0x50FFFFFED35A2FA158 represents 80.99999993% with
     *         an invisible decimal point in between 0x50 and 0xFFFFFED35A2FA158.
     */
    function getUtilisationRate() external view override returns (uint256) {
        // https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
        // slither-disable-next-line incorrect-equality
        if (totalUnderlyingAssetAmount == 0) {
            return 0;
        }

        // https://github.com/crytic/slither/wiki/Detector-Documentation#too-many-digits
        // slither-disable-next-line too-many-digits
        require(
            totalLoanedUnderlyingAssetAmount <
                0x0010000000000000000000000000000000000000000,
            "TreasuryPool: overflow"
        );

        uint256 dividend = totalLoanedUnderlyingAssetAmount.mul(100) << 64;
        return dividend.div(totalUnderlyingAssetAmount);
    }

    function getTotalUnderlyingAssetAvailableCore()
        internal
        view
        returns (uint256)
    {
        return totalUnderlyingAssetAmount.sub(totalLoanedUnderlyingAssetAmount);
    }

    function getTotalUnderlyingAssetAvailable()
        external
        view
        override
        returns (uint256)
    {
        return getTotalUnderlyingAssetAvailableCore();
    }

    function setGovernanceAccount(address newGovernanceAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newGovernanceAccount != address(0),
            "TreasuryPool: new governance account is the zero address"
        );

        governanceAccount = newGovernanceAccount;
    }

    function setFarmingPoolAccount(address newFarmingPoolAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newFarmingPoolAccount != address(0),
            "TreasuryPool: new farming pool account is the zero address"
        );

        farmingPoolAccount = newFarmingPoolAccount;
    }

    function pause() external onlyBy(governanceAccount) {
        _pause();
    }

    function unpause() external onlyBy(governanceAccount) {
        _unpause();
    }

    function sweep(address to) external override onlyBy(governanceAccount) {
        require(
            to != address(0),
            "TreasuryPool: the address to be swept is the zero address"
        );

        uint256 balance = _underlyingAsset.balanceOf(address(this));
        // https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities
        // slither-disable-next-line incorrect-equality
        if (balance == 0) {
            return;
        }

        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.sub(balance);

        emit Sweep(
            address(this),
            to,
            underlyingAssetAddress,
            balance,
            msg.sender,
            block.timestamp
        );

        _underlyingAsset.safeTransfer(to, balance);
    }

    function _divExchangeRate(uint256 amount) private returns (uint256) {
        require(
            farmingPoolAccount != address(0),
            "TreasuryPool: farming pool account not initialized"
        );

        if (totalLtokenAmount > 0) {
            uint256 borrowerInterestEarning =
                IFarmingPool(farmingPoolAccount)
                    .computeBorrowerInterestEarning();
            // amount/((totalUnderlyingAssetAmount+borrowerInterestEarning)/totalLtokenAmount)
            return
                amount.mul(totalLtokenAmount).div(
                    totalUnderlyingAssetAmount.add(borrowerInterestEarning)
                );
        } else {
            return amount;
        }
    }

    function _mulExchangeRate(uint256 amount) private returns (uint256) {
        require(
            farmingPoolAccount != address(0),
            "TreasuryPool: farming pool account not initialized"
        );

        if (totalLtokenAmount > 0) {
            uint256 borrowerInterestEarning =
                IFarmingPool(farmingPoolAccount)
                    .computeBorrowerInterestEarning();
            // amount*((totalUnderlyingAssetAmount+borrowerInterestEarning)/totalLtokenAmount)
            return
                amount
                    .mul(
                    totalUnderlyingAssetAmount.add(borrowerInterestEarning)
                )
                    .div(totalLtokenAmount);
        } else {
            return amount;
        }
    }
}