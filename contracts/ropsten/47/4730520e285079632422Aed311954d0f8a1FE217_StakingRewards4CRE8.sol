// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol"; 
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { StableMath } from "./StableMath.sol";
import "hardhat/console.sol";

contract StakingTokenWrapper4CRE8 is ReentrancyGuard { 
    
    using SafeERC20 for IERC20;
    // using SafeMath for uint256;
    using StableMath for uint256;

    event Transfer(address indexed from, address indexed to, uint256 value);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    IERC20 public immutable stakingToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address _stakingToken, string memory _nameArg, string memory _symbolArg) { 
        stakingToken = IERC20(_stakingToken); 
        name = _nameArg;
        symbol = _symbolArg;
    }

    function totalSupply() public view returns (uint256) { return _totalSupply; }
    function balanceOf(address _account) public view returns (uint256) { return _balances[_account]; }

    function _stake(address _beneficiary, uint256 _amount) internal virtual nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + _amount;
        _balances[_beneficiary] = _balances[_beneficiary] + _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Transfer(address(0), _beneficiary, _amount);
    }

    function _withdraw(uint256 _amount) internal nonReentrant {
        require(_amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= _amount, "Not enough user staked");
        _totalSupply = _totalSupply - _amount;
        _balances[msg.sender] = _balances[msg.sender] - _amount;
        stakingToken.safeTransfer(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }
}

contract StakingRewards4CRE8 is StakingTokenWrapper4CRE8, Ownable { 
    
    // using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using StableMath for uint256;

    uint public lastPauseTime;
    bool public paused;

    struct StakingEntry { // struct for saving each staking entry
        uint256 initialValue;
        uint256 value;
        uint256 stakingTimestamp;
        uint256 lastClaimedTime;
        uint256 totalRewards;
        uint256 claimableRewards;
        uint256 fullDaysStaked;
        bool rewardStatus;
    }

    /// @notice token the rewards are distributed in. eg MTA
    IERC20 public immutable rewardToken; 

    /// @notice length of each staking period in seconds. 7 days = 604,800; 3 months = 7,862,400
    // uint256 public immutable DURATION = 1 days;
    // uint256 public immutable LOCK_DURATION = 30;
    uint256 public immutable DURATION = 1 minutes;
    uint256 public immutable LOCK_DURATION = 1;

    // uint256 public immutable rewardsPerDay = 100 * 1000 * (10 ** 18); // 100k per day
    uint256 public immutable rewardsPerDay = 100 * (10 ** 18); // 100k per day
    
    mapping(address => StakingEntry[]) public stakingEntries;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(uint256 => uint256) public stakedPerDay;

    event Staked(address indexed user, uint256 amount, address payer);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Recovered(address token, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        address _stakingToken
    ) StakingTokenWrapper4CRE8(
        _stakingToken,
        _name,
        _symbol
    ) {
        rewardToken = IERC20(_stakingToken); 
    }
    
    function stake(uint256 _amount) external {
        _stake(msg.sender, _amount);
    }
    
    function stake(address _beneficiary, uint256 _amount) external {
        _stake(_beneficiary, _amount);
    }

    function _stake(address _beneficiary, uint256 _amount) internal override notPaused {
        super._stake(_beneficiary, _amount);
        uint256 nowtime = block.timestamp;
        stakingEntries[_beneficiary].push(StakingEntry(_amount, _amount, nowtime, 0, 0, 0, 0, false));
        emit Staked(_beneficiary, _amount, msg.sender);
        stakedPerDay[uint256(nowtime / DURATION)] = totalSupply();
    }

    /** 
        @dev Withdraws given stake amount from the pool @param _amount Units of the staked token to withdraw 
    */
    function withdraw(uint256 _amount, uint256 entryIndex) external {
        require(_amount > 0, "Cannot withdraw 0");
        require(_amount <= stakingEntries[msg.sender][entryIndex].value, "Cannot withdraw 0");
        uint256 additionalRewards = 0;
        uint256 i;
        uint256 j;
        uint256 k;
        uint256 nowtime = block.timestamp;
        uint256 toDay = uint256(nowtime / DURATION);
        uint256 fromDay;
        uint256 claimAmt;
        if (stakingEntries[msg.sender][entryIndex].lastClaimedTime == 0) {
            fromDay = uint256(stakingEntries[msg.sender][entryIndex].stakingTimestamp / DURATION);
        } else {
            fromDay = uint256(stakingEntries[msg.sender][entryIndex].lastClaimedTime / DURATION);
        }

        for (i = fromDay; i < toDay; i++) {
            if (stakedPerDay[i] == 0) {
                for (j = i - 1; j >= fromDay; j--) {
                    if (stakedPerDay[j] != 0) {
                        break;
                    }
                }
                for (k = j+1; k < i+1; k++)
                    stakedPerDay[k] = stakedPerDay[j];
            }

            additionalRewards = additionalRewards + divPrecisely(rewardsPerDay, stakedPerDay[i]) * stakingEntries[msg.sender][entryIndex].value;
        }
        additionalRewards = additionalRewards / 1e18;
        stakingEntries[msg.sender][entryIndex].totalRewards = stakingEntries[msg.sender][entryIndex].totalRewards + additionalRewards;
        stakingEntries[msg.sender][entryIndex].claimableRewards = stakingEntries[msg.sender][entryIndex].claimableRewards + additionalRewards;
        stakingEntries[msg.sender][entryIndex].lastClaimedTime = nowtime;
        stakingEntries[msg.sender][entryIndex].fullDaysStaked = uint256(nowtime / DURATION) - uint256(stakingEntries[msg.sender][entryIndex].stakingTimestamp / DURATION);
        claimAmt = divPrecisely(stakingEntries[msg.sender][entryIndex].claimableRewards, stakingEntries[msg.sender][entryIndex].value) * _amount;        
        claimAmt = claimAmt / 1e18;
        if (uint256(nowtime / DURATION) - uint256(stakingEntries[msg.sender][entryIndex].stakingTimestamp / DURATION) > LOCK_DURATION)
            claimReward(entryIndex, claimAmt);
        else {
            stakingEntries[msg.sender][entryIndex].claimableRewards = stakingEntries[msg.sender][entryIndex].claimableRewards - claimAmt;
        }
        stakingEntries[msg.sender][entryIndex].value = stakingEntries[msg.sender][entryIndex].value - _amount;
        _withdraw(_amount);
        emit Withdrawn(msg.sender, _amount);
        stakedPerDay[uint256(nowtime / DURATION)] = totalSupply();
    }
    
    /** 
        @dev Claims outstanding rewards for the sender. First updates outstanding reward allocation and then transfers. 
    */
    function claimReward(uint256 entryIndex, uint256 _amount) public {
        require(uint256(block.timestamp / DURATION) - uint256(stakingEntries[msg.sender][entryIndex].stakingTimestamp / DURATION) > LOCK_DURATION, "Locked for 1 month");
        uint256 additionalRewards = 0;
        uint256 i;
        uint256 j;
        uint256 k;
        uint256 nowtime = block.timestamp;
        uint256 toDay = uint256(nowtime / DURATION);
        uint256 fromDay;
        if (stakingEntries[msg.sender][entryIndex].lastClaimedTime == 0) {
            fromDay = uint256(stakingEntries[msg.sender][entryIndex].stakingTimestamp / DURATION);
        } else {
            fromDay = uint256(stakingEntries[msg.sender][entryIndex].lastClaimedTime / DURATION);
        }

        for (i = fromDay; i < toDay; i++) {
            if (stakedPerDay[i] == 0) {
                for (j = i - 1; j >= fromDay; j--) {
                    if (stakedPerDay[j] != 0) {
                        break;
                    }
                }
                for (k = j+1; k < i+1; k++)
                    stakedPerDay[k] = stakedPerDay[j];
            }
            additionalRewards = additionalRewards + divPrecisely(rewardsPerDay, stakedPerDay[i]) * stakingEntries[msg.sender][entryIndex].value;
        }
        additionalRewards = additionalRewards / 1e18;
        stakingEntries[msg.sender][entryIndex].totalRewards = stakingEntries[msg.sender][entryIndex].totalRewards + additionalRewards;
        stakingEntries[msg.sender][entryIndex].claimableRewards = stakingEntries[msg.sender][entryIndex].claimableRewards + additionalRewards;
        stakingEntries[msg.sender][entryIndex].lastClaimedTime = nowtime;
        stakingEntries[msg.sender][entryIndex].fullDaysStaked = uint256(nowtime / DURATION) - uint256(stakingEntries[msg.sender][entryIndex].stakingTimestamp / DURATION);
        stakingEntries[msg.sender][entryIndex].rewardStatus = true;

        require(stakingEntries[msg.sender][entryIndex].claimableRewards > 0, "No reward");
        require(stakingEntries[msg.sender][entryIndex].claimableRewards >= _amount, "Insufficient reward");

        stakingEntries[msg.sender][entryIndex].claimableRewards = stakingEntries[msg.sender][entryIndex].claimableRewards - _amount;
        rewardToken.safeTransfer(msg.sender, _amount);
        emit RewardPaid(msg.sender, _amount);
    }

    function fetchHistory(address staker) external view returns(StakingEntry[] memory) {
        StakingEntry[] memory history = new StakingEntry[](stakingEntries[staker].length);
        uint256 i;
        uint256 j;
        uint256 k;
        uint256 stakedDay;
        uint256 additionalRewards;
        uint256 nowtime = block.timestamp;
        uint256 toDay = uint256(nowtime / DURATION);
        uint256 fromDay;

        for (i = 0; i < history.length; i++) {
            history[i].initialValue = stakingEntries[staker][i].initialValue;
            history[i].value = stakingEntries[staker][i].value;
            history[i].stakingTimestamp = stakingEntries[staker][i].stakingTimestamp;
            history[i].lastClaimedTime = stakingEntries[staker][i].lastClaimedTime;
            history[i].totalRewards = stakingEntries[staker][i].totalRewards;
            history[i].claimableRewards = stakingEntries[staker][i].claimableRewards;
            history[i].fullDaysStaked = stakingEntries[staker][i].fullDaysStaked;
            history[i].rewardStatus = stakingEntries[staker][i].rewardStatus;
        }
        
        for (i = 0; i < history.length; i++) {
            additionalRewards = 0;
            if (history[i].lastClaimedTime == 0) {
                fromDay = uint256(history[i].stakingTimestamp / DURATION);
            } else {
                fromDay = uint256(history[i].lastClaimedTime / DURATION);
            }

            for (j = fromDay; j < toDay; j++) {
                stakedDay = stakedPerDay[j];
                if ( stakedDay == 0) {
                    for (k = j - 1; k >= fromDay; k--) {
                        if (stakedPerDay[k] != 0) {
                            break;
                        }
                    }
                    stakedDay = stakedPerDay[k];
                }
                additionalRewards = additionalRewards + divPrecisely(rewardsPerDay, stakedDay) * history[i].value;
            }
            additionalRewards = additionalRewards / 1e18;
            history[i].totalRewards = history[i].totalRewards + additionalRewards;
            history[i].claimableRewards = history[i].claimableRewards + additionalRewards;
            history[i].lastClaimedTime = nowtime;
            history[i].fullDaysStaked = uint256(nowtime / DURATION) - uint256(history[i].stakingTimestamp / DURATION);
            history[i].rewardStatus = uint256(nowtime / DURATION) - uint256(history[i].stakingTimestamp / DURATION) > LOCK_DURATION ? true : false;
        }

        return history;
    }

    function adjustReward(int256 rewardDelta) external onlyOwner { 
        if (rewardDelta > 0) { rewardToken.transferFrom(this.owner(), address(this), uint256(rewardDelta)); }
        else { rewardToken.transfer(this.owner(), uint256(-rewardDelta)); }
    }    

    uint256 FULL_SCALE = 1e18;

    function divPrecisely(uint256 x, uint256 y) internal view returns (uint256) {
        // e.g. 8e18 * 1e18 = 8e36
        // e.g. 8e36 / 10e18 = 8e17
        return (x * FULL_SCALE) / y;
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).safeTransfer(this.owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = getTimestamp();
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }

    function getTimestamp() public view virtual returns (uint256) {
        return block.timestamp;
    }
}