// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../libs/Math.sol";
import "../libs/SafeMath.sol";
import "../libs/IERC20.sol";
import "../libs/SafeERC20.sol";
import "./ConvexInterfaces.sol";
import "../common/IVirtualBalanceWrapper.sol";

// contract ConvexRewardPool {
//     using SafeMath for uint256;
//     using SafeERC20 for IERC20;

//     IERC20 public rewardToken;
//     IERC20 public stakingToken;
//     uint256 public constant duration = 7 days;

//     address public operator;

//     // uint256 public pid;
//     uint256 public periodFinish = 0;
//     uint256 public rewardRate = 0;
//     uint256 public lastUpdateTime;
//     uint256 public rewardPerTokenStored;
//     uint256 public queuedRewards = 0;
//     uint256 public currentRewards = 0;
//     uint256 public historicalRewards = 0;
//     uint256 public constant newRewardRatio = 830;
//     uint256 private _totalSupply;
//     mapping(address => uint256) public userRewardPerTokenPaid;
//     mapping(address => uint256) public rewards;
//     mapping(address => uint256) private _balances;

//     address[] public extraRewards;

//     event RewardAdded(uint256 reward);
//     event Staked(address indexed user, uint256 amount);
//     event Withdrawn(address indexed user, uint256 amount);
//     event RewardPaid(address indexed user, uint256 reward);

//     constructor(
//         // uint256 pid_,
//         address stakingToken_,
//         address rewardToken_,
//         address operator_
//     ) public {
//         // pid = pid_;
//         stakingToken = IERC20(stakingToken_);
//         rewardToken = IERC20(rewardToken_);
//         operator = operator_;
//     }

//     function totalSupply() public view returns (uint256) {
//         return _totalSupply;
//     }

//     function balanceOf(address account) public view returns (uint256) {
//         return _balances[account];
//     }

//     function extraRewardsLength() external view returns (uint256) {
//         return extraRewards.length;
//     }

//     function addExtraReward(address _reward) external returns (bool) {
//         // require(msg.sender == rewardManager, "!authorized");
//         require(_reward != address(0), "!reward setting");

//         extraRewards.push(_reward);
//         return true;
//     }

//     function clearExtraRewards() external {
//         // require(msg.sender == rewardManager, "!authorized");
//         delete extraRewards;
//     }

//     modifier updateReward(address account) {
//         rewardPerTokenStored = rewardPerToken();
//         lastUpdateTime = lastTimeRewardApplicable();
//         if (account != address(0)) {
//             rewards[account] = earned(account);
//             userRewardPerTokenPaid[account] = rewardPerTokenStored;
//         }
//         _;
//     }

//     function lastTimeRewardApplicable() public view returns (uint256) {
//         return Math.min(block.timestamp, periodFinish);
//     }

//     function rewardPerToken() public view returns (uint256) {
//         if (totalSupply() == 0) {
//             return rewardPerTokenStored;
//         }
//         return
//             rewardPerTokenStored.add(
//                 lastTimeRewardApplicable()
//                     .sub(lastUpdateTime)
//                     .mul(rewardRate)
//                     .mul(1e18)
//                     .div(totalSupply())
//             );
//     }

//     function earned(address account) public view returns (uint256) {
//         return
//             balanceOf(account)
//                 .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
//                 .div(1e18)
//                 .add(rewards[account]);
//     }

//     function stake(uint256 _amount)
//         public
//         updateReward(msg.sender)
//         returns (bool)
//     {
//         require(_amount > 0, "RewardPool : Cannot stake 0");

//         //also stake to linked rewards
//         for (uint256 i = 0; i < extraRewards.length; i++) {
//             IConvexRewardPool(extraRewards[i]).stake(msg.sender, _amount);
//         }

//         _totalSupply = _totalSupply.add(_amount);
//         _balances[msg.sender] = _balances[msg.sender].add(_amount);

//         stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
//         emit Staked(msg.sender, _amount);

//         return true;
//     }

//     function stakeAll() external returns (bool) {
//         uint256 balance = stakingToken.balanceOf(msg.sender);
//         stake(balance);
//         return true;
//     }

//     function stakeFor(address _for, uint256 _amount)
//         public
//         updateReward(_for)
//         returns (bool)
//     {
//         require(_amount > 0, "RewardPool : Cannot stake 0");

//         //also stake to linked rewards
//         for (uint256 i = 0; i < extraRewards.length; i++) {
//             IConvexRewardPool(extraRewards[i]).stake(_for, _amount);
//         }

//         //give to _for
//         _totalSupply = _totalSupply.add(_amount);
//         _balances[_for] = _balances[_for].add(_amount);

//         //take away from sender
//         stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
//         emit Staked(_for, _amount);

//         return true;
//     }

//     function withdraw(uint256 amount, bool claim)
//         public
//         updateReward(msg.sender)
//         returns (bool)
//     {
//         require(amount > 0, "RewardPool : Cannot withdraw 0");

//         //also withdraw from linked rewards
//         for (uint256 i = 0; i < extraRewards.length; i++) {
//             IConvexRewardPool(extraRewards[i]).withdraw(msg.sender, amount);
//         }

//         _totalSupply = _totalSupply.sub(amount);
//         _balances[msg.sender] = _balances[msg.sender].sub(amount);

//         stakingToken.safeTransfer(msg.sender, amount);
//         emit Withdrawn(msg.sender, amount);

//         if (claim) {
//             getReward(msg.sender, true);
//         }

//         return true;
//     }

//     function withdrawAll(bool claim) external {
//         withdraw(_balances[msg.sender], claim);
//     }

//     /* function withdrawAndUnwrap(uint256 amount, bool claim) public updateReward(msg.sender) returns(bool){

//         //also withdraw from linked rewards
//         for(uint i=0; i < extraRewards.length; i++){
//             IConvexRewardPool(extraRewards[i]).withdraw(msg.sender, amount);
//         }

//         _totalSupply = _totalSupply.sub(amount);
//         _balances[msg.sender] = _balances[msg.sender].sub(amount);

//         //tell operator to withdraw from here directly to user
//         IDeposit(operator).withdrawTo(pid,amount,msg.sender);

//         emit Withdrawn(msg.sender, amount);

//         //get rewards too
//         if(claim){
//             getReward(msg.sender,true);
//         }
//         return true;
//     }

//     function withdrawAllAndUnwrap(bool claim) external{
//         withdrawAndUnwrap(_balances[msg.sender],claim);
//     } */

//     function getReward(address _account, bool _claimExtras)
//         public
//         updateReward(_account)
//         returns (bool)
//     {
//         uint256 reward = earned(_account);
//         if (reward > 0) {
//             rewards[_account] = 0;
//             rewardToken.safeTransfer(_account, reward);
//             // 挖 cvx
//             // IDeposit(operator).rewardClaimed(pid, _account, reward);
//             emit RewardPaid(_account, reward);
//         }

//         //also get rewards from linked rewards
//         if (_claimExtras) {
//             for (uint256 i = 0; i < extraRewards.length; i++) {
//                 IConvexRewardPool(extraRewards[i]).getReward(_account);
//             }
//         }
//         return true;
//     }

//     function getReward() external returns (bool) {
//         getReward(msg.sender, true);
//         return true;
//     }

//     function donate(uint256 _amount) external returns (bool) {
//         IERC20(rewardToken).safeTransferFrom(
//             msg.sender,
//             address(this),
//             _amount
//         );
//         queuedRewards = queuedRewards.add(_amount);
//     }

//     function queueNewRewards(uint256 _rewards) external returns (bool) {
//         require(msg.sender == operator, "!authorized");

//         _rewards = _rewards.add(queuedRewards);

//         if (block.timestamp >= periodFinish) {
//             notifyRewardAmount(_rewards);
//             queuedRewards = 0;
//             return true;
//         }

//         //et = now - (finish-duration)
//         uint256 elapsedTime = block.timestamp.sub(periodFinish.sub(duration));
//         //current at now: rewardRate * elapsedTime
//         uint256 currentAtNow = rewardRate * elapsedTime;
//         uint256 queuedRatio = currentAtNow.mul(1000).div(_rewards);

//         //uint256 queuedRatio = currentRewards.mul(1000).div(_rewards);
//         if (queuedRatio < newRewardRatio) {
//             notifyRewardAmount(_rewards);
//             queuedRewards = 0;
//         } else {
//             queuedRewards = _rewards;
//         }
//         return true;
//     }

//     function notifyRewardAmount(uint256 reward)
//         internal
//         updateReward(address(0))
//     {
//         historicalRewards = historicalRewards.add(reward);
//         if (block.timestamp >= periodFinish) {
//             rewardRate = reward.div(duration);
//         } else {
//             uint256 remaining = periodFinish.sub(block.timestamp);
//             uint256 leftover = remaining.mul(rewardRate);
//             reward = reward.add(leftover);
//             rewardRate = reward.div(duration);
//         }
//         currentRewards = reward;
//         lastUpdateTime = block.timestamp;
//         periodFinish = block.timestamp.add(duration);
//         emit RewardAdded(reward);
//     }
// }
contract ConvexRewardPool {
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

    address[] public extraRewards;

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

    function extraRewardsLength() external view returns (uint256) {
        return extraRewards.length;
    }

    function addExtraReward(address _reward) external returns (bool) {
        // require(msg.sender == rewardManager, "!authorized");
        require(_reward != address(0), "!reward setting");

        extraRewards.push(_reward);
        return true;
    }

    function clearExtraRewards() external {
        // require(msg.sender == rewardManager, "!authorized");
        delete extraRewards;
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

contract ConvexRewardFactory {
    function CreateRewards(
        address _reward,
        address _virtualBalance,
        address _operator
    ) external returns (address) {
        ConvexRewardPool rewardPool = new ConvexRewardPool(
            _reward,
            _virtualBalance,
            _operator
        );

        return address(rewardPool);
    }
}