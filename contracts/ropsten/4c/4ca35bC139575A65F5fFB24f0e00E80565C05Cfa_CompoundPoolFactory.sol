// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../libs/Math.sol";
import "../libs/SafeMath.sol";
import "../libs/SafeERC20.sol";
import "./CompoundInterfaces.sol";
import "../common/IVirtualBalanceWrapper.sol";

// import "./CompoundRewardPool.sol";
// import "./CompoundInterestRewardPool.sol";
// import "./CompoundTreasuryFund.sol";

contract CompoundTreasuryFund {
    using SafeERC20 for IERC20;

    address public operator;
    event WithdrawTo(address indexed user, uint256 amount);

    constructor(address _op) public {
        operator = _op;
    }

    function withdrawTo(
        address _asset,
        uint256 _amount,
        address _to
    ) external {
        require(msg.sender == operator, "!authorized");

        IERC20(_asset).safeTransfer(_to, _amount);

        emit WithdrawTo(_to, _amount);
    }

    function claimComp(
        address _comp,
        address _comptroller,
        address _to
    ) external returns (uint256) {
        ICompoundComptroller(_comptroller).claimComp(address(this));

        uint256 balanceOfComp = IERC20(_comp).balanceOf(address(this));

        if (balanceOfComp > 0) {
            IERC20(_comp).safeTransfer(_to, balanceOfComp);
        }

        return balanceOfComp;
    }
}

contract CompoundRewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public rewardToken;
    // uint256 public constant duration = 7 days;
    uint256 public constant duration = 10 minutes;

    address public operator;
    address public virtualBalance;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    uint256 public newRewardRatio = 830;
    // uint256 private _totalSupply;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    // mapping(address => uint256) private _balances;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _reward,
        address _virtualBalance,
        address _op
    ) public {
        rewardToken = _reward;
        virtualBalance = _virtualBalance;
        operator = _op;
    }

    function totalSupply() public view returns (uint256) {
        return IVirtualBalanceWrapper(virtualBalance).totalSupply();
    }

    function balanceOf(address _for) public view returns (uint256) {
        return IVirtualBalanceWrapper(virtualBalance).balanceOf(_for);
    }

    modifier updateReward(address _for) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_for != address(0)) {
            rewards[_for] = earned(_for);
            userRewardPerTokenPaid[_for] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address _for) public view returns (uint256) {
        return
            balanceOf(_for)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[_for]))
                .div(1e18)
                .add(rewards[_for]);
    }

    function getReward(address _for) public updateReward(_for) {
        uint256 reward = earned(_for);
        if (reward > 0) {
            rewards[_for] = 0;
            if (rewardToken != address(0)) {
                IERC20(rewardToken).safeTransfer(_for, reward);
            } else {
                payable(_for).transfer(reward);
            }

            emit RewardPaid(_for, reward);
        }
    }

    function getReward() external {
        getReward(msg.sender);
    }

    function donate(uint256 _amount) external payable returns (bool) {
        if (rewardToken != address(0)) {
            IERC20(rewardToken).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
            queuedRewards = queuedRewards.add(_amount);
        } else {
            queuedRewards = queuedRewards.add(msg.value);
        }
    }

    function queueNewRewards(uint256 _rewards) external {
        require(msg.sender == operator, "!authorized");

        _rewards = _rewards.add(queuedRewards);

        if (block.timestamp >= periodFinish) {
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
            return;
        }

        //et = now - (finish-duration)
        uint256 elapsedTime = block.timestamp.sub(periodFinish.sub(duration));
        //current at now: rewardRate * elapsedTime
        uint256 currentAtNow = rewardRate * elapsedTime;
        uint256 queuedRatio = currentAtNow.mul(1000).div(_rewards);
        if (queuedRatio < newRewardRatio) {
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
        } else {
            queuedRewards = _rewards;
        }
    }

    function notifyRewardAmount(uint256 _reward)
        internal
        updateReward(address(0))
    {
        historicalRewards = historicalRewards.add(_reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = _reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);

            _reward = _reward.add(leftover);
            rewardRate = _reward.div(duration);
        }

        currentRewards = _reward;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);

        emit RewardAdded(_reward);
    }

    receive() external payable {}
}

contract CompoundPoolFactory {
    function CreateCompoundRewardPool(
        address rewardToken,
        address virtualBalance,
        address op
    ) public returns (address) {
        CompoundRewardPool pool = new CompoundRewardPool(
            rewardToken,
            virtualBalance,
            op
        );

        return address(pool);
    }

    function CreateCompoundInterestRewardPool(
        address rewardToken,
        address virtualBalance,
        address op
    ) public returns (address) {
        return CreateCompoundRewardPool(rewardToken, virtualBalance, op);
    }

    function CreateTreasuryFundPool(address op) public returns (address) {
        CompoundTreasuryFund pool = new CompoundTreasuryFund(op);

        return address(pool);
    }
}