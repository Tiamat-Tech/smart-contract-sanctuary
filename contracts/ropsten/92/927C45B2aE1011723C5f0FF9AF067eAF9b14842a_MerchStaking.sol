// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "hardhat/console.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract MerchStaking is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint equivalentAmount;
        uint rewardOut;
    }

    // Info of each pool.
    struct Pool {
        uint stakingCap; // Pool staking tokens limit
        uint rewardCap; // Pool reward tokens limit
        uint rewardAPY; // scaledBy 1e18
        uint startTime; 
        uint endTime; 
        uint tokenRate; // 1LP/MRCH scaledBy 1e18
        bool bEnded;
    }
    Pool[] public pools;

    mapping(address => Stake) public stakes;

    address public stakeToken; // Uniswap LP token from pool MRCH/USDT
    address public rewardToken; // MRCH token

    uint public constant blocksPerYear = 2102400;
    uint public rewardRatePerBlock;

    address public admin;

    event Staked(address staker, uint amount, uint equivalent);
    event RewardOut(address staker, address token, uint amount);

    constructor(
        address _stakeToken,
        address _rewardToken
    ) {
        admin = msg.sender;

        require(_stakeToken != address(0), "MerchStaking: stake token address is 0");
        stakeToken = _stakeToken;

        require(_rewardToken != address(0), "MerchStaking: reward token address is 0");
        rewardToken = _rewardToken;
    }

    function test1() public returns (address, address) {
        address _token0 = IUniswapV2Pair(stakeToken).token0();
        address _token1 = IUniswapV2Pair(stakeToken).token1();
        return (_token0, _token1);
    }

    function test2() public returns (address, address) {
        address _token0 = IUniswapV2Pair(rewardToken).token0();
        address _token1 = IUniswapV2Pair(rewardToken).token1();
        return (_token0, _token1);
    }
    
    function addPool(uint _rewardAPY, uint _startTime, uint _endTime, uint _tokenRate) public onlyOwner {
        // pools.push(
        //     Pool({
        //     rewardAPY: _rewardAPY,
        //     startTime: _startTime,
        //     endTime: _endTime,
        //     tokenRate: _tokenRate
        //     })
        // );
    }
    // function addReward(uint rewardAmount) public returns (bool) {
    //     require(rewardAmount > 0, "MerchStaking: reward must be positive");

    //     transferIn(msg.sender, rewardToken, rewardAmount);

    //     allReward = allReward.add(rewardAmount);

    //     return true;
    // }

    // function removeUnusedReward() public returns (bool) {
    //     require(getTimeStamp() > stakingEnd, "MerchStaking: bad timing for the request");
    //     require(msg.sender == admin, "MerchStaking: Only admin can remove unused reward");

    //     uint unusedReward = allReward.sub(calcReward(stakedTotal));
    //     allReward = allReward.sub(unusedReward);

    //     transferOut(rewardToken, admin, unusedReward);

    //     return true;
    // }

    function stake(uint _pid, uint _amount) public returns (bool) {
        // require(_amount > 0, "MerchStaking: must be positive");
        // require(getTimeStamp() >= pools[_pid].startTime, "MerchStaking: bad timing for the request");
        // require(getTimeStamp() < pools[_pid].endTime, "MerchStaking: bad timing for the request");

        // address staker = msg.sender;
        // uint equivalent = calcRewardTokenEquivalent(_amount);

        // if (equivalent > (stakingCap.sub(stakedTotal))) {
        //     uint newEquivalent = stakingCap.sub(stakedTotal);
        //     uint coefficient = newEquivalent.mul(1e18).div(equivalent);
        //     equivalent = newEquivalent;
        //     amount = amount.mul(coefficient).div(1e18);
        // }

        // require(equivalent > 0, "MerchStaking: Staking cap is filled");
        // require(equivalent.add(stakedTotal) <= stakingCap, "MerchStaking: this will increase staking amount pass the cap");

        // transferIn(staker, stakeToken, amount);

        // emit Staked(staker, amount, equivalent);

        // // Transfer is completed
        // stakedTotal = stakedTotal.add(equivalent);
        // stakes[staker].amount = stakes[staker].amount.add(amount);
        // stakes[staker].equivalentAmount = stakes[staker].equivalentAmount.add(equivalent);

        // return true;
    }

    // function withdraw() public returns (bool) {
    //     require(claimReward(), "MerchStaking: claim error");
    //     uint amount = stakes[msg.sender].amount;

    //     return withdrawWithoutReward(amount);
    // }

    // function withdrawWithoutReward(uint amount) public returns (bool) {
    //     return withdrawInternal(msg.sender, amount);
    // }

    // function withdrawInternal(address staker, uint amount) internal returns (bool) {
    //     require(getTimeStamp() >= withdrawStart, "MerchStaking: bad timing for the request");
    //     require(amount > 0, "MerchStaking: must be positive");
    //     require(amount <= stakes[msg.sender].amount, "MerchStaking: not enough balance");

    //     stakes[staker].amount = stakes[staker].amount.sub(amount);

    //     transferOut(stakeToken, staker, amount);

    //     return true;
    // }

    // function claimReward() public returns (bool) {
    //     require(getTimeStamp() > stakingEnd, "MerchStaking: bad timing for the request");

    //     address staker = msg.sender;

    //     uint rewardAmount = currentReward(staker);

    //     if (rewardAmount == 0) {
    //         return true;
    //     }

    //     transferOut(rewardToken, staker, rewardAmount);

    //     stakes[staker].rewardOut = stakes[staker].rewardOut.add(rewardAmount);

    //     emit RewardOut(staker, rewardToken, rewardAmount);

    //     return true;
    // }

    // function calcTotalReward(address staker) public view returns (uint) {
    //     uint amount = stakes[staker].equivalentAmount;

    //     return calcReward(amount);
    // }

    // function calcReward(uint amount) public view returns (uint) {
    //     uint duration = withdrawStart.sub(stakingEnd);

    //     // .div(15) - 1 eth block is mine every ~15 sec, rewardRatePerBlock scaled by 1e18, and 100 is %
    //     uint rewardAmount = amount.mul(rewardRatePerBlock).mul(duration).div(15).div(1e18).div(100);
    //     return rewardAmount;
    // }

    // function currentReward(address staker) public view returns (uint) {
    //     uint totalStakerReward = calcTotalReward(staker);
    //     uint timeStamp = getTimeStamp();

    //     if (totalStakerReward == 0 || timeStamp < stakingEnd) {
    //         return 0;
    //     }

    //     uint allTime = withdrawStart.sub(stakingEnd);

    //     uint time = timeStamp < withdrawStart ? timeStamp.sub(stakingEnd) : allTime;

    //     uint stakerRewardToTimestamp = totalStakerReward.mul(time).div(allTime); // 1 eth block is mine every ~15 sec
    //     uint rewardOut = stakes[staker].rewardOut;

    //     return stakerRewardToTimestamp.sub(rewardOut);
    // }

    function calcRewardTokenEquivalent(uint amount) public view returns (uint) {
        uint decimalsRewardToken = ERC20(rewardToken).decimals();
        uint decimalsStakeToken = ERC20(stakeToken).decimals();
        uint factor;

        if (decimalsStakeToken >= decimalsRewardToken) {
            factor = 10**(decimalsStakeToken - decimalsRewardToken);
        } else {
            factor = 10**(decimalsRewardToken - decimalsStakeToken);
        }

        address _token0 = IUniswapV2Pair(stakeToken).token0();
        address _token1 = IUniswapV2Pair(stakeToken).token1();

        uint balance = rewardToken == _token0 ? (IERC20(_token0).balanceOf(stakeToken)) : (IERC20(_token1).balanceOf(stakeToken));
        return amount.mul(factor).mul(2).mul(balance).div(IERC20(stakeToken).totalSupply());
    }

    function transferOut(address token, address to, uint amount) internal {
        if (amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransfer(to, amount);
    }

    function transferIn(address from, address token, uint amount) internal {
        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransferFrom(from, address(this), amount);
    }

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }
}