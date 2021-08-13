//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {IRhoTokenRewards} from "../interfaces/IRhoTokenRewards.sol";
import {BaseRewards} from "./BaseRewards.sol";
import {IFlurryStakingRewards} from "../interfaces/IFlurryStakingRewards.sol";

/**
 * @title Rewards for RhoToken Holders
 * @notice This reward scheme enables users to earn FLURRY tokens by holding rhoTokens.
 * NOTE: Users do not need to deposit rhoTokens into this contract. Simply holding suffices.
 */
contract RhoTokenRewards is IRhoTokenRewards, BaseRewards {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // events
    event RhoTokenRewardsRateChanged(uint256 blockNumber, uint256 rewardsRate);
    event RhoTokenRewardsEndUpdated(address indexed rhoTokenAddr, uint256 blockNumber, uint256 rewardsEndBlock);
    event RhoTokenAdded(address indexed rhoTokenAddr);

    // role of Flurry Staking Rewards contract
    bytes32 public constant FLURRY_STAKING_REWARDS_ROLE = keccak256("FLURRY_STAKING_REWARDS_ROLE");

    // rhoToken reward scheme params
    uint256 public override rewardsRate;
    uint256 public totalAllocPoint; // total allocation points = sum of allocation points in all rhoTokens
    address[] private rhoTokenList;

    // rhoToken params
    struct RhoTokenInfo {
        // Note: obtain rhoToken total supply by external call. Not stored as a state here
        IERC20Upgradeable rhoToken; // reference to underlying RhoToken
        uint256 allocPoint; // allocation points (weight) assigned to this rhoToken
        uint256 rewardPerToken; // accumulated reward per RhoToken
        uint256 lastUpdateBlock; // block number that reward was last accrued at
        uint256 rewardEndBlock; // the last block when reward distubution ends
        uint256 rhoTokenOne; // multiplier for one unit of RhoToken
    }
    mapping(address => RhoTokenInfo) public rhoTokenInfo;
    mapping(address => bool) public override isSupported;

    // user info
    struct UserInfo {
        // Note: obtain user's rhoToken balance by external call. Not stored as a state here
        uint256 rewardPerTokenPaid; // amount of reward already paid to user per token
        uint256 reward; // accumulated reward for each user
    }
    mapping(address => mapping(address => UserInfo)) public userInfo;

    IFlurryStakingRewards public override flurryStakingRewards;

    function initialize(address flurryStakingRewardsAddr) public initializer {
        BaseRewards.__initialize();
        flurryStakingRewards = IFlurryStakingRewards(flurryStakingRewardsAddr);
    }

    function getRhoTokenList() external view override returns (address[] memory) {
        return rhoTokenList;
    }

    function setRewardsRate(uint256 newRewardsRate) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        updateRewardForAll();
        rewardsRate = newRewardsRate;
        emit RhoTokenRewardsRateChanged(block.number, rewardsRate);
    }

    function rewardOf(address user, address rhoToken)
        external
        view
        override
        isSupportedRhoToken(rhoToken)
        returns (uint256)
    {
        return _earned(user, rhoToken);
    }

    function totalRewardOf(address user) external view override returns (uint256) {
        uint256 totalReward = 0;
        for (uint256 i = 0; i < rhoTokenList.length; i++) {
            totalReward += _earned(user, rhoTokenList[i]);
        }
        return totalReward;
    }

    function rewardsPerToken(address rhoToken) public view override isSupportedRhoToken(rhoToken) returns (uint256) {
        uint256 totalSupply = rhoTokenInfo[rhoToken].rhoToken.totalSupply();
        if (totalSupply == 0) return rhoTokenInfo[rhoToken].rewardPerToken;
        return
            rewardPerTokenInternal(
                rhoTokenInfo[rhoToken].rewardPerToken,
                lastBlockApplicable(rhoToken) - rhoTokenInfo[rhoToken].lastUpdateBlock,
                rewardRatePerTokenInternal(
                    rewardsRate,
                    rhoTokenInfo[rhoToken].rhoTokenOne,
                    rhoTokenInfo[rhoToken].allocPoint,
                    totalSupply,
                    totalAllocPoint
                )
            );
    }

    function rewardRatePerRhoToken(address rhoToken)
        external
        view
        override
        isSupportedRhoToken(rhoToken)
        returns (uint256)
    {
        if (totalAllocPoint == 0) return type(uint256).max;
        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        uint256 totalSupply = _rhoToken.rhoToken.totalSupply();
        if (totalSupply == 0) return type(uint256).max;
        return
            rewardRatePerTokenInternal(
                rewardsRate,
                _rhoToken.rhoTokenOne,
                _rhoToken.allocPoint,
                totalSupply,
                totalAllocPoint
            );
    }

    function lastBlockApplicable(address rhoToken) internal view returns (uint256) {
        return _lastBlockApplicable(rhoTokenInfo[rhoToken].rewardEndBlock);
    }

    function _earned(address user, address rhoToken) internal view returns (uint256) {
        UserInfo storage _user = userInfo[rhoToken][user];
        return
            super._earned(
                IERC20Upgradeable(rhoToken).balanceOf(user),
                rewardsPerToken(rhoToken) - _user.rewardPerTokenPaid,
                rhoTokenInfo[rhoToken].rhoTokenOne,
                _user.reward
            );
    }

    function updateRewardInternal(address rhoToken) internal {
        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        _rhoToken.rewardPerToken = rewardsPerToken(rhoToken);
        _rhoToken.lastUpdateBlock = lastBlockApplicable(rhoToken);
    }

    function updateReward(address user, address rhoToken) public override isSupportedRhoToken(rhoToken) {
        updateRewardInternal(rhoToken);
        if (user != address(0)) {
            userInfo[rhoToken][user].reward = _earned(user, rhoToken);
            userInfo[rhoToken][user].rewardPerTokenPaid = rhoTokenInfo[rhoToken].rewardPerToken;
        }
    }

    function updateRewardForAll() internal {
        for (uint256 i = 0; i < rhoTokenList.length; i++) {
            updateRewardInternal(rhoTokenList[i]);
        }
    }

    function startRewards(address rhoToken, uint256 rewardDuration)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        isSupportedRhoToken(rhoToken)
        isValidDuration(rewardDuration)
    {
        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        require(
            block.number > _rhoToken.rewardEndBlock,
            "Previous rewards period must complete before starting a new one"
        );
        updateRewardInternal(rhoToken);
        _rhoToken.lastUpdateBlock = block.number;
        _rhoToken.rewardEndBlock = block.number + rewardDuration;
        emit RhoTokenRewardsEndUpdated(rhoToken, block.number, _rhoToken.rewardEndBlock);
    }

    function endRewards(address rhoToken)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        isSupportedRhoToken(rhoToken)
    {
        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        if (_rhoToken.rewardEndBlock > block.number) {
            _rhoToken.rewardEndBlock = block.number;
            emit RhoTokenRewardsEndUpdated(rhoToken, block.number, _rhoToken.rewardEndBlock);
        }
    }

    function claimRewardInternal(address user, address rhoToken) internal {
        updateReward(user, rhoToken);
        UserInfo storage _user = userInfo[rhoToken][user];
        if (_user.reward > 0) {
            _user.reward = flurryStakingRewards.grantFlurry(user, _user.reward);
        }
    }

    function claimReward(address onBehalfOf, address rhoToken)
        external
        override
        onlyRole(FLURRY_STAKING_REWARDS_ROLE)
        whenNotPaused
        nonReentrant
        claimerNotZeroAddr(onBehalfOf)
    {
        claimRewardInternal(onBehalfOf, rhoToken);
    }

    function claimReward(address rhoToken) external override whenNotPaused nonReentrant {
        claimRewardInternal(_msgSender(), rhoToken);
    }

    function claimAllRewardInternal(address user) internal claimerNotZeroAddr(user) {
        for (uint256 i = 0; i < rhoTokenList.length; i++) {
            claimRewardInternal(user, rhoTokenList[i]);
        }
    }

    function claimAllReward(address onBehalfOf)
        external
        override
        onlyRole(FLURRY_STAKING_REWARDS_ROLE)
        whenNotPaused
        nonReentrant
        claimerNotZeroAddr(onBehalfOf)
    {
        claimAllRewardInternal(onBehalfOf);
    }

    function claimAllReward() external override whenNotPaused nonReentrant {
        claimAllRewardInternal(_msgSender());
    }

    function addRhoToken(address rhoToken, uint256 allocPoint)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        notSupportedRhoToken(rhoToken)
    {
        updateRewardForAll();
        totalAllocPoint += allocPoint;
        rhoTokenList.push(rhoToken);
        rhoTokenInfo[rhoToken] = RhoTokenInfo({
            rhoToken: IERC20Upgradeable(rhoToken),
            allocPoint: allocPoint,
            lastUpdateBlock: block.number,
            rewardPerToken: 0,
            rewardEndBlock: 0,
            rhoTokenOne: getTokenOne(rhoToken)
        });
        isSupported[rhoToken] = true;
        emit RhoTokenAdded(rhoToken);
    }

    function setRhoToken(address rhoToken, uint256 allocPoint)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        isSupportedRhoToken(rhoToken)
    {
        updateRewardForAll();
        totalAllocPoint = totalAllocPoint - rhoTokenInfo[rhoToken].allocPoint + allocPoint;
        rhoTokenInfo[rhoToken].allocPoint = allocPoint;
    }

    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        _sweepERC20Token(token, to);
    }

    modifier isSupportedRhoToken(address rhoToken) {
        require(isSupported[rhoToken], "rhoToken not supported");
        _;
    }

    modifier notSupportedRhoToken(address rhoToken) {
        require(!isSupported[rhoToken], "rhoToken already registered");
        _;
    }
}