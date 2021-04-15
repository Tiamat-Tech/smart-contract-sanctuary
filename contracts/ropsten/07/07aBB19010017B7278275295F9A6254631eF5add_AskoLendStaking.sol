pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAskoStaking.sol";
import "./interfaces/IStakeHandler.sol";
import "hardhat/console.sol";

contract AskoLendStaking is IStakeHandler {
    using SafeMath for uint256;

    uint256 internal constant MULTIPLIER = 2**64;
    uint256 public totalAvailableRewards;
    uint256 public totalRegistered;
    uint256 public totalStakedFromRegistered;
    uint256 private askoPerShare;
    uint256 private emptyStakeTokens;

    IERC20 private askoToken;
    IAskoStaking private askoStaking;

    mapping(address => bool) public isStakerRegistered;
    mapping(address => uint256) public stakerPayouts;
    mapping(address => uint256) public stakeValue;

    event OnClaim(address sender, uint256 payout);
    event OnRegister(address sender);

    constructor(address _askoToken, address _askoStaking) {
        askoToken = IERC20(_askoToken);
        askoStaking = IAskoStaking(_askoStaking);
    }

    modifier onlyFromAskoStaking {
        require(
            msg.sender == address(askoStaking),
            "Sender must be AskoStaking sc."
        );
        _;
    }

    function handleStake(
        address staker,
        uint256 stakerDeltaValue,
        uint256 _stakeValue
    ) external override onlyFromAskoStaking {
        if (!isStakerRegistered[staker]) return;
        totalStakedFromRegistered = totalStakedFromRegistered.add(
            stakerDeltaValue
        );

        uint256 payout = askoPerShare.mul(_stakeValue);
        stakerPayouts[staker] = stakerPayouts[staker].add(payout);
        stakeValue[staker] += _stakeValue;
        _increaseAskoPerShare(totalAvailableRewards);
    }

    function handleUnstake(
        address staker,
        uint256 stakerDeltaValue,
        uint256 _stakeValue
    ) external override onlyFromAskoStaking {
        if (!isStakerRegistered[staker]) return;
        totalStakedFromRegistered = totalStakedFromRegistered.sub(
            stakerDeltaValue
        );

        uint256 payout = askoPerShare.mul(_stakeValue);
        stakerPayouts[staker] = stakerPayouts[staker].sub(payout);
        stakeValue[staker] -= _stakeValue;
        _increaseAskoPerShare(totalAvailableRewards);
    }

    function distribute(uint256 amount) public {
        require(
            askoToken.balanceOf(msg.sender) >= amount,
            "Not enough asko to donate."
        );

        totalAvailableRewards = totalAvailableRewards.add(
            amount.mul(99).div(100)
        ); // increase available reward amount
        askoToken.transferFrom(msg.sender, address(this), amount);

        _increaseAskoPerShare(totalAvailableRewards);
    }

    function register() public {
        require(!isStakerRegistered[msg.sender], "Staker already registered.");
        isStakerRegistered[msg.sender] = true;
        totalRegistered = totalRegistered.add(1);

        uint256 staked = askoStaking.stakeValue(msg.sender);
        stakeValue[msg.sender] = staked;

        totalStakedFromRegistered = totalStakedFromRegistered.add(staked); // update total staked

        uint256 payout = askoPerShare.mul(staked);
        stakerPayouts[msg.sender] = stakerPayouts[msg.sender].add(payout);

        emit OnRegister(msg.sender);
    }

    function claim(uint256 amount) public {
        require(isStakerRegistered[msg.sender], "Staker is not registered");
        require(
            getDividends(msg.sender) >= amount,
            "Claiming more rewards than owned"
        );

        uint256 payout = amount.mul(MULTIPLIER);
        stakerPayouts[msg.sender] = stakerPayouts[msg.sender].add(payout);
        askoToken.transfer(msg.sender, amount);

        emit OnClaim(msg.sender, amount);
    }

    function getDividends(address staker) public view returns (uint256) {
        require(isStakerRegistered[staker], "Staker is not registered");
        uint256 dividends =
            askoPerShare.mul(stakeValue[staker]).sub(stakerPayouts[staker]);
        dividends = dividends.div(MULTIPLIER);

        return dividends;
    }

    function _increaseAskoPerShare(uint256 amount) internal {
        if (totalStakedFromRegistered != 0) {
            if (emptyStakeTokens != 0) {
                amount = amount.add(emptyStakeTokens);
                emptyStakeTokens = 0;
            }
            askoPerShare = askoPerShare.add(
                amount.mul(MULTIPLIER).div(totalStakedFromRegistered)
            );
            totalAvailableRewards -= amount;
        } else {
            emptyStakeTokens = emptyStakeTokens.add(amount);
        }
    }
}