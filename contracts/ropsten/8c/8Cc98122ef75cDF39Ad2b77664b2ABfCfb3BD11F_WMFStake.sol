// SPDX-License-Identifier: MIT
pragma solidity =0.6.6;

import "../module/Math/SafeMath.sol";
import "../module/ERC20/SafeERC20.sol";
import "../module/Common/Ownable.sol";
import "../module/Utils/ReentrancyGuard.sol";
import "../We_Made_Future.sol";

contract WMFStake is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many WMF tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 depositSecond;
    }

    // Info of each stake.
    struct StakeInfo {
        IERC20 StakeToken;           // Address of Stake token contract.
        uint256 lastRewardSecond;  // Last second that WMFs distribution occurs.
        uint256 accWMFPerShare;   // Accumulated WMFs per share, times 1e18. See below.
        uint256 totalSupply;
    }

    // The WMF TOKEN!
    We_Made_Future public immutable WMF;
    // Dev address.
    address public devaddr;
    // WMF tokens created per second.
    uint256 public WMFPerSecond;
    // Info of each stake.
    StakeInfo[] public stakeInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // The block timestamp when WMF mining starts.
    uint256 public startTime;

    uint256 public lock_time_min = 86400;

    // Maximum WMFPerTime
    uint256 public constant MAX_EMISSION_RATE = 500000000000000000;

    constructor(
        We_Made_Future _WMF,
        address _devaddr,
        uint256 _WMFPerTime,
        uint256 _startTime
    ) public {
        WMF = _WMF;
        devaddr = _devaddr;
        WMFPerSecond = _WMFPerTime;
        startTime = _startTime;
    }

    function stakeLength() external view returns (uint256) {
        return stakeInfo.length;
    }

    // Return reward multiplier over the given _from to _to block.
    function getStakingduration(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending WMFs on frontend.
    function pendingWMF(uint256 _sid, address _user) external view returns (uint256) {
        StakeInfo storage stake = stakeInfo[_sid];
        UserInfo storage user = userInfo[_sid][_user];
        uint256 accWMFPerShare = stake.accWMFPerShare;
        if (block.timestamp > stake.lastRewardSecond && stake.totalSupply != 0) {
            accWMFPerShare = accWMFPerShare.add(WMFPerSecond.mul(1e18).div(stake.totalSupply));
        }
        return user.amount.mul(accWMFPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables of the given stake to be up-to-date.
    function updateStake(uint256 _sid) public {
        StakeInfo storage stake = stakeInfo[_sid];
        if (block.timestamp <= stake.lastRewardSecond) {
            return;
        }
        if (stake.totalSupply == 0) {
            stake.lastRewardSecond = block.timestamp;
            return;
        }
        uint256 WMFReward = WMFPerSecond;
        
        try WMF.pool_mint(devaddr, WMFReward.div(10)) {
        } catch (bytes memory reason) {
            WMFReward = 0;
            emit WMFMintError(reason);
        }
        
        try WMF.pool_mint(address(this), WMFReward) {
        } catch (bytes memory reason) {
            WMFReward = 0;
            emit WMFMintError(reason);
        }
        
        stake.accWMFPerShare = stake.accWMFPerShare.add(WMFReward.mul(1e18).div(stake.totalSupply));
        stake.lastRewardSecond = block.timestamp;
    }
    
    // Deposit LP tokens to MasterChef for WMF allocation.
    function deposit(uint256 _sid, uint256 _amount) external nonReentrant {
        StakeInfo storage stake = stakeInfo[_sid];
        UserInfo storage user = userInfo[_sid][msg.sender];
        updateStake(_sid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(stake.accWMFPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                safeWMFTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 balanceBefore = stake.StakeToken.balanceOf(address(this));
            stake.StakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            _amount = stake.StakeToken.balanceOf(address(this)).sub(balanceBefore);

            user.amount = user.amount.add(_amount);
            stake.totalSupply = stake.totalSupply.add(_amount);
        }
        user.depositSecond = block.timestamp;
        user.rewardDebt = user.amount.mul(stake.accWMFPerShare).div(1e18);
        emit Deposit(msg.sender, _sid, _amount);
    }

    // Withdraw LP tokens from WMFChef.
    function withdraw(uint256 _sid, uint256 _amount) external nonReentrant {
        StakeInfo storage stake = stakeInfo[_sid];
        UserInfo storage user = userInfo[_sid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        require(getStakingduration(user.depositSecond, block.timestamp) >= lock_time_min, "Minimum stake time not met");
        updateStake(_sid);
        uint256 pending = user.amount.mul(stake.accWMFPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            safeWMFTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            stake.StakeToken.safeTransfer(address(msg.sender), _amount);
            stake.totalSupply = stake.totalSupply.sub(_amount);
        }

        user.rewardDebt = user.amount.mul(stake.accWMFPerShare).div(1e18);
        emit Withdraw(msg.sender, _sid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _sid) external nonReentrant {
        StakeInfo storage stake = stakeInfo[_sid];
        UserInfo storage user = userInfo[_sid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        stake.StakeToken.safeTransfer(address(msg.sender), amount);

        if (stake.totalSupply >=  amount) {
            stake.totalSupply = stake.totalSupply.sub(amount);
        } else {
            stake.totalSupply = 0;
        }

        emit EmergencyWithdraw(msg.sender, _sid, amount);
    }

    // Safe WMF transfer function, just in case if rounding error causes stake to not have enough WMFs.
    function safeWMFTransfer(address _to, uint256 _amount) internal {
        uint256 WMFBal = WMF.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > WMFBal) {
            transferSuccess = WMF.transfer(_to, WMFBal);
        } else {
            transferSuccess = WMF.transfer(_to, _amount);
        }
        require(transferSuccess, "safeWMFTransfer: transfer failed");
    }

    // Update dev address.
    function setDevAddress(address _devaddr) external {
        require(msg.sender == devaddr, "dev: wut?");
        require(_devaddr != address(0), "!nonzero");

        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }

 // Pancake has to add hidden dummy stakes inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _WMFPerSecond) external onlyOwner {
        require(_WMFPerSecond <= MAX_EMISSION_RATE, "Too high");
        WMFPerSecond = _WMFPerSecond;
        emit UpdateEmissionRate(msg.sender, _WMFPerSecond);
    }

    // Only update before start of farm
    function updateStartTime(uint256 _newStartTime) external onlyOwner {
        require(block.timestamp < startTime, "cannot change start time if farm has already started");
        require(block.timestamp < _newStartTime, "cannot set start time in the past");
        uint256 length = stakeInfo.length;
        for (uint256 sid = 0; sid < length; ++sid) {
            StakeInfo storage stake = stakeInfo[sid];
            stake.lastRewardSecond = _newStartTime;
        }
        startTime = _newStartTime;

        emit UpdateStartTime(startTime);
    }


    event Deposit(address indexed user, uint256 indexed sid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed sid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed sid, uint256 amount);
    event SetDevAddress(address indexed user, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 WMFPerSecond);
    event UpdateStartTime(uint256 newStartTime);
    event WMFMintError(bytes reason);

}