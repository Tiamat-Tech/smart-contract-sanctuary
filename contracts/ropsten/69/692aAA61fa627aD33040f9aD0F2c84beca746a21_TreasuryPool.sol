// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ILfi.sol";
import "./interfaces/ILtoken.sol";
import "./interfaces/IDsecDistribution.sol";

contract TreasuryPool is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public constant LP_REWARD_PER_EPOCH = 4000 ether;
    uint256 public constant TEAM_REWARD_PER_EPOCH = 1000 ether;

    address public governanceAccount;
    address public lfiAddress;
    address public underlyingAssetAddress;
    address public ltokenAddress;
    address public teamAccount;
    address public dsecDistributionAddress;

    uint256 public totalUnderlyingAssetAmount = 0;
    uint256 public totalLtokenAmount = 0;

    ILfi private _lfi;
    IERC20 private _underlyingAsset;
    ILtoken private _ltoken;
    IDsecDistribution private _dsecDistribution;

    event AddLiquidity(
        address indexed account,
        address indexed underlyingAssetAddress,
        uint256 amount,
        uint256 timestamp
    );

    event RemoveLiquidity(
        address indexed account,
        address indexed underlyingAssetAddress,
        uint256 amount,
        uint256 timestamp
    );

    event RedeemProviderReward(
        address indexed account,
        uint256 indexed fromEpoch,
        uint256 indexed toEpoch,
        address rewardTokenAddress,
        uint256 amount,
        uint256 timestamp
    );

    event RedeemTeamReward(
        address indexed account,
        uint256 indexed fromEpoch,
        uint256 indexed toEpoch,
        address rewardTokenAddress,
        uint256 amount,
        uint256 timestamp
    );

    event Sweep(
        address indexed from,
        address indexed to,
        address indexed underlyingAssetAddress,
        uint256 amount,
        address operator
    );

    constructor(
        address lfiAddress_,
        address underlyingAssetAddress_,
        address ltokenAddress_,
        address teamAccount_,
        address dsecDistributionAddress_
    ) {
        require(
            lfiAddress_ != address(0),
            "Pool: LFI address is the zero address"
        );
        require(
            underlyingAssetAddress_ != address(0),
            "Pool: underlying asset address is the zero address"
        );
        require(
            ltokenAddress_ != address(0),
            "Pool: LToken address is the zero address"
        );
        require(
            teamAccount_ != address(0),
            "Pool: team account is the zero address"
        );
        require(
            dsecDistributionAddress_ != address(0),
            "Pool: dsec distribution address is the zero address"
        );

        governanceAccount = msg.sender;
        lfiAddress = lfiAddress_;
        underlyingAssetAddress = underlyingAssetAddress_;
        ltokenAddress = ltokenAddress_;
        teamAccount = teamAccount_;
        dsecDistributionAddress = dsecDistributionAddress_;

        _lfi = ILfi(lfiAddress_);
        _underlyingAsset = IERC20(underlyingAssetAddress_);
        _ltoken = ILtoken(ltokenAddress);
        _dsecDistribution = IDsecDistribution(dsecDistributionAddress_);
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "Pool: sender not authorized");
        _;
    }

    function addLiquidity(uint256 amount) external nonReentrant {
        require(amount != 0, "Pool: can't add 0");
        require(!paused(), "Pool: deposit while paused");

        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.add(amount);
        totalLtokenAmount = totalLtokenAmount.add(amount);

        emit AddLiquidity(
            msg.sender,
            underlyingAssetAddress,
            amount,
            block.timestamp
        );

        _underlyingAsset.safeTransferFrom(msg.sender, address(this), amount);
        _dsecDistribution.addDsec(msg.sender, amount);
        _ltoken.mint(msg.sender, amount);
    }

    function removeLiquidity(uint256 amount) external nonReentrant {
        require(amount != 0, "Pool: can't remove 0");
        require(!paused(), "Pool: withdraw while paused");
        require(
            totalUnderlyingAssetAmount >= amount,
            "Pool: insufficient liquidity"
        );
        require(
            _ltoken.balanceOf(msg.sender) >= amount,
            "Pool: insufficient LToken"
        );

        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.sub(amount);
        totalLtokenAmount = totalLtokenAmount.sub(amount);

        emit RemoveLiquidity(
            msg.sender,
            underlyingAssetAddress,
            amount,
            block.timestamp
        );

        _ltoken.burn(msg.sender, amount);
        _dsecDistribution.removeDsec(msg.sender, amount);
        _underlyingAsset.safeTransfer(msg.sender, amount);
    }

    function redeemProviderReward(uint256 fromEpoch, uint256 toEpoch) external {
        require(fromEpoch <= toEpoch, "Pool: invalid epoch range");
        require(!paused(), "Pool: redeem while paused");

        uint256 totalRewardAmount = 0;
        for (uint256 i = fromEpoch; i <= toEpoch; i++) {
            if (_dsecDistribution.hasRedeemedDsec(msg.sender, i)) {
                break;
            }

            uint256 rewardAmount =
                _dsecDistribution.redeemDsec(
                    msg.sender,
                    i,
                    LP_REWARD_PER_EPOCH
                );
            totalRewardAmount = totalRewardAmount.add(rewardAmount);
        }

        if (totalRewardAmount == 0) {
            return;
        }

        _lfi.mint(msg.sender, totalRewardAmount);

        emit RedeemProviderReward(
            msg.sender,
            fromEpoch,
            toEpoch,
            lfiAddress,
            totalRewardAmount,
            block.timestamp
        );
    }

    function redeemTeamReward(uint256 fromEpoch, uint256 toEpoch)
        external
        onlyBy(teamAccount)
    {
        require(fromEpoch <= toEpoch, "Pool: invalid epoch range");
        require(!paused(), "Pool: redeem while paused");

        uint256 totalRewardAmount = 0;
        for (uint256 i = fromEpoch; i <= toEpoch; i++) {
            if (_dsecDistribution.hasRedeemedTeamReward(i)) {
                break;
            }

            _dsecDistribution.redeemTeamReward(i);
            totalRewardAmount = totalRewardAmount.add(TEAM_REWARD_PER_EPOCH);
        }

        if (totalRewardAmount == 0) {
            return;
        }

        _lfi.mint(teamAccount, totalRewardAmount);

        emit RedeemTeamReward(
            teamAccount,
            fromEpoch,
            toEpoch,
            lfiAddress,
            totalRewardAmount,
            block.timestamp
        );
    }

    function setGovernanceAccount(address to)
        external
        onlyBy(governanceAccount)
    {
        governanceAccount = to;
    }

    function pause() external onlyBy(governanceAccount) {
        _pause();
    }

    function unpause() external onlyBy(governanceAccount) {
        _unpause();
    }

    function sweep(address to) external onlyBy(governanceAccount) {
        uint256 balance = _underlyingAsset.balanceOf(address(this));
        if (balance == 0) {
            return;
        }

        totalUnderlyingAssetAmount = totalUnderlyingAssetAmount.sub(balance);
        _underlyingAsset.safeTransfer(to, balance);

        emit Sweep(
            address(this),
            to,
            underlyingAssetAddress,
            balance,
            msg.sender
        );
    }
}