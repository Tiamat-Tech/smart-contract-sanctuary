// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./GoldenPearl.sol";

contract Booster is Initializable, Ownable, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for GoldenPearl;

    uint256 public PRECISION_FACTOR;

    // The reward token
    GoldenPearl public goldenPearl;

    // The staked token: pearl
    IERC20 public stakedToken;

    uint256 public startBlock;

    uint256 public lastRewardBlock;

    uint256 public lastBurnBlock;

    uint256 public accTokenPerShare;

    uint256 public bonusEndBlock;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    MonthlyReward[] public slices;

    struct UserInfo {
        // uint256 amount; // How many staked tokens the user has provided
        //uint256 rewardDebt; // Reward debt
        //uint256 share; // relative share of amount because staked tokens get burned
        uint256 amountRatio;
        uint256 rewardDebtRatio;
    }

    // holds the token reward for every months
    struct MonthlyReward {
        uint index;
        uint256 startBlock;
        uint256 endBlock;
        uint256 rewardPerBlock;
    }

    uint256 public BLOCKS_PER_MONTH;

    // events
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event BurnStakedToken(uint256 amount);

    // constructor(
    //     GoldenPearl _goldenPearl,
    //     ERC20 _stakedToken,
    //     uint256 _startBlock,
    //     uint256[] memory monthlyRewardsInWei,
    //     uint256 _blockPerSec,
    //     address _admin
    // ) {

    // }

    function initialize(
        GoldenPearl _goldenPearl,
        ERC20 _stakedToken,
        uint256 _startBlock,
        uint256[] memory monthlyRewardsInWei,
        uint256 _blockPerSec,
        address _admin
    ) public initializer {
        goldenPearl = _goldenPearl;
        stakedToken = _stakedToken;
        startBlock = _startBlock;

        BLOCKS_PER_MONTH = (60 / _blockPerSec) * 60 * 24 * 30;

        createMonthlyRewardSlices(monthlyRewardsInWei);

        lastRewardBlock = startBlock;
        lastBurnBlock = startBlock;
        bonusEndBlock = slices[slices.length-1].endBlock;

        uint256 decimalsRewardToken = uint256(goldenPearl.decimals());
        require(decimalsRewardToken < 30, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(30).sub(decimalsRewardToken)));

        transferOwnership(_admin);
    }


    function createMonthlyRewardSlices(uint256[] memory monthlyRewardsInWei) private {
        uint256 currentBlock = startBlock;
        for(uint i=0; i < monthlyRewardsInWei.length; i++) {
            slices.push(MonthlyReward({
                index: i,
                startBlock: currentBlock,
                endBlock: currentBlock + BLOCKS_PER_MONTH,
                rewardPerBlock: monthlyRewardsInWei[i]
            }));
            currentBlock = currentBlock + BLOCKS_PER_MONTH + 1;
        }
    }

    function addRewards(uint256[] memory monthlyRewardsInWei) external onlyOwner {
        MonthlyReward memory lastSlice = slices[slices.length -1];
        uint256 currentBlock = lastSlice.endBlock + 1;
        uint256 startIndex = lastSlice.index + 1;
        for(uint i=0; i < monthlyRewardsInWei.length; i++) {
            slices.push(MonthlyReward({
                index: startIndex,
                startBlock: currentBlock,
                endBlock: currentBlock + BLOCKS_PER_MONTH,
                rewardPerBlock: monthlyRewardsInWei[i]
            }));
            startIndex += startIndex + 1;
            currentBlock = currentBlock + BLOCKS_PER_MONTH + 1;
        }
    }

    /*
     * @notice Deposit staked tokens and harvest golden pearl if _amount = 0
     * @param _amount: amount to deposit, 
     */
    function deposit(uint256 _amount) external nonReentrant {
         UserInfo storage user = userInfo[msg.sender];

         _updatePool();

        uint256 userAmount = _toAbsoluteAmount(user.amountRatio);
        uint256 rewardDebt = _toAbsoluteAmount(user.rewardDebtRatio);

        if (userAmount > 0) {
            uint256 pending = userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(rewardDebt);
            if (pending > 0) {
                goldenPearl.safeTransfer(address(msg.sender), pending);
            }
        }

        if (_amount > 0) {
            userAmount = userAmount.add(_amount);
            stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);

            user.amountRatio = _toRatio(userAmount);
            // user.share = user.amount.mul(PRECISION_FACTOR).div(stakedToken.balanceOf(address(this)));
        }

        rewardDebt = userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR);
        user.rewardDebtRatio = _toRatio(rewardDebt);

        emit Deposit(msg.sender, _amount);

        _burnStakedTokens();
    }

    function _toAbsoluteAmount(uint256 _amountRatio) internal view returns (uint256) {
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        return stakedTokenSupply.mul(_amountRatio).div(PRECISION_FACTOR);
    }

    function _toRatio(uint256 _amount) internal view returns (uint256) {
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        if (stakedTokenSupply == 0) {
            return 0;
        }
        return _amount.mul(PRECISION_FACTOR).div(stakedTokenSupply);
    }


   
    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     * TODO since we burning stakedtokens the user only gets his percentage of tokens not the absolute amount
     */
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        uint256 userAmount = _toAbsoluteAmount(user.amountRatio);
        uint256 rewardDebt = _toAbsoluteAmount(user.rewardDebtRatio);
        require(userAmount >= _amount, "Amount to withdraw too high");

        _updatePool();

        uint256 pending = userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(rewardDebt);

        if (_amount > 0) {
            userAmount = userAmount.sub(_amount);

            //since we burning stake tokens max we need to check the max amount
           // uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));

          //  console.log("StakedToken Supply %s", stakedTokenSupply);
            // console.log("Abs User Amount %s", userAmount);
            // console.log("_Amount %s", _amount);

            user.amountRatio = _toRatio(userAmount);

            stakedToken.safeTransfer(address(msg.sender), _amount);
        }

        if (pending > 0) {
            // console.log("Withdraw pending gp %s", pending);
            // console.log("Withdraw balanceOf gp %s", goldenPearl.balanceOf(address(this)));
            goldenPearl.safeTransfer(address(msg.sender), pending);
        }

        rewardDebt = userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR);
        user.rewardDebtRatio = _toRatio(rewardDebt);

        emit Withdraw(msg.sender, _amount);

        _burnStakedTokens();
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = _toAbsoluteAmount(user.amountRatio);
        user.amountRatio = 0;
        user.rewardDebtRatio = 0;

        if (amountToTransfer > 0) {
            stakedToken.safeTransfer(address(msg.sender), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amountRatio);
    }


    function getUserInfo(address _user) external view returns (uint256 userAmount, uint256 rewardDebt) {
         UserInfo storage user = userInfo[_user];
         return (_toAbsoluteAmount(user.amountRatio), _toAbsoluteAmount(user.rewardDebtRatio));
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        goldenPearl.safeTransfer(address(msg.sender), _amount);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        uint256 userAmount = _toAbsoluteAmount(user.amountRatio);
        uint256 rewardDebt = _toAbsoluteAmount(user.rewardDebtRatio);

        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            MonthlyReward memory fromSlice = getMonthlyReward(lastRewardBlock);
            MonthlyReward memory toSlice = getMonthlyReward(block.number);

            uint256 gpReward = _rewardForSlices(fromSlice, toSlice);
            uint256 adjustedTokenPerShare =
                accTokenPerShare.add(gpReward.mul(PRECISION_FACTOR).div(stakedTokenSupply));
            
            return userAmount.mul(adjustedTokenPerShare).div(PRECISION_FACTOR).sub(rewardDebt);
        } else {
            return userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(rewardDebt);
        }
    }


    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));

        if (stakedTokenSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }

        MonthlyReward memory fromSlice = getMonthlyReward(lastRewardBlock);
        MonthlyReward memory toSlice = getMonthlyReward(block.number);

        uint256 gpReward = _rewardForSlices(fromSlice, toSlice);

        goldenPearl.mint(address(this), gpReward);

        accTokenPerShare = accTokenPerShare.add(gpReward.mul(PRECISION_FACTOR).div(stakedTokenSupply));
    
        lastRewardBlock = block.number;
    }


    function _burnStakedTokens() internal {
        if (block.number <= lastBurnBlock) {
            return;
        }

        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        if (stakedTokenSupply == 0) {
            lastBurnBlock = block.number;
            return;
        }
        
        uint256 burnRatio = (block.number - lastBurnBlock).div(1000).mul(2); // burn 2% of every 1000th block; Fixpoint: 0.02 * 100 = 2
        uint256 burnAmount = stakedTokenSupply.mul(burnRatio).div(100);  // correct by 100

        stakedToken.safeTransfer(0x000000000000000000000000000000000000dEaD, burnAmount);

        lastBurnBlock = block.number;

        emit BurnStakedToken(burnAmount);
    }


    function burningRate() external view returns (uint256 burnAmount) {

        // percentage = x * 10000 => 2% = 200, 20% = 2000

        uint256 _supply = stakedToken.balanceOf(address(this));

        // console.log("StakedToken Supply %s", _supply);
        // console.log("Block Number %s", block.number);
        // console.log("LastBurnBlock %s", lastBurnBlock);

        uint256 burnRatio = (block.number - lastBurnBlock).div(1000).mul(2); // burn 2% of every 1000th block; 0.02 * 100 = 2% 
        // console.log("Burn FixPoint Ratio %s", burnRatio);

        // console.log("Burn Amount %s", _supply.mul(burnRatio));

        burnAmount = _supply.mul(burnRatio).div(100);  // correct by 100
        // console.log("Total supply after burn %s", _supply - burnAmount);

        // burn 2% of every 1000th block
        return burnAmount;
    }

    function getMonthlyReward(uint256 blockNumber) public view returns (MonthlyReward memory) {
        for (uint i = 0; i < slices.length; i++) {
            MonthlyReward memory slice = slices[i];
            if (blockNumber >= slice.startBlock && blockNumber <= slice.endBlock) {
                return slice;
            }
        } 
        return slices[slices.length -1];
    }

    function _rewardForSlices(MonthlyReward memory fromSlice, MonthlyReward memory toSlice) internal view returns (uint256 reward) {
        if (block.number >= bonusEndBlock) {
            return 0;
        }

        if (fromSlice.index == toSlice.index) {
            return (block.number - lastRewardBlock) * toSlice.rewardPerBlock;
        }

        uint rewardsInBetween = 0;
        if (fromSlice.index < toSlice.index) {

            // first: rewards for the raimining blocks of the fromSlice
            uint256 firstBlocks = fromSlice.endBlock - lastRewardBlock;
            uint256 firstBlockReward = firstBlocks * fromSlice.rewardPerBlock;

            // second: rewards for all the blocks between
            if (toSlice.index - fromSlice.index > 1) {
                //sum up all rewards
                for(uint i = (fromSlice.index + 1); i < toSlice.index; i++) {
                    MonthlyReward memory currentSlice = slices[i];
                   rewardsInBetween += ((currentSlice.endBlock - currentSlice.startBlock) * currentSlice.rewardPerBlock);
                }     
            }

            //third: rewards for the block of the toSlice
            uint256 lastBlocks = block.number - toSlice.startBlock;
            uint256 lastBlockReward = lastBlocks * toSlice.rewardPerBlock;

            return firstBlockReward + rewardsInBetween + lastBlockReward;
        }
    }

    

}