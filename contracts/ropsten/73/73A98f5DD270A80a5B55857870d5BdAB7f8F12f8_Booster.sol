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

import "hardhat/console.sol";

contract Booster is Initializable, Ownable, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeMath for uint32;
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

    uint256 public burnMultiplier;

    uint256 public burnBlockQuota;

    uint256 public totalBurnedPearl;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    MonthlyReward[] public slices;

    struct UserInfo {
        // uint256 amount; // How many staked tokens the user has provided
        //uint256 rewardDebt; // Reward debt
        //uint256 share; // relative share of amount because staked tokens get burned
        uint256 amount;
        uint256 rewardDebt;
        uint256 lockedAt;
        uint256 lastUserBurnBlock;
    }

   // stakedPearl = amount - amount * (block.number - user.lastBurnBlock) / 1000 * 2%


    // holds the token reward for every months
    struct MonthlyReward {
        uint index;
        uint256 startBlock;
        uint256 endBlock;
        uint256 rewardPerBlock;
    }

    uint256 public BLOCKS_PER_MONTH;

    address public BURNING_ADDRESS;

    uint32 blocks_locked;

    // events
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event BurnStakedToken(uint256 amount);
    event UpdateBurnMultiplier(address indexed user, uint256 indexed multiplier);
    event UpdateBurnBlockQuota(address indexed user, uint256 indexed blockQuota);

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

        BURNING_ADDRESS = 0x000000000000000000000000000000000000dEaD;

        burnMultiplier = 2;

        burnBlockQuota = 1000;

        blocks_locked = (60 / uint32(_blockPerSec)) * 60 * 24; 

        totalBurnedPearl = 0;
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
        uint startIndex = lastSlice.index + 1;
        for(uint i=0; i < monthlyRewardsInWei.length; i++) {
            slices.push(MonthlyReward({
                index: startIndex,
                startBlock: currentBlock,
                endBlock: currentBlock + BLOCKS_PER_MONTH,
                rewardPerBlock: monthlyRewardsInWei[i]
            }));
            startIndex = startIndex + 1;
            currentBlock = currentBlock + BLOCKS_PER_MONTH + 1;
        }
        bonusEndBlock = slices[slices.length-1].endBlock;
    }

    /*
     * @notice Deposit staked tokens and harvest golden pearl if _amount = 0
     * @param _amount: amount to deposit, 
     */
    function deposit(uint256 _amount) external nonReentrant {
         UserInfo storage user = userInfo[msg.sender];

         _updatePool();

        _burnStakedTokens();
        _correctUserAmountAccordingToLastBurn(user);

        console.log("deposit userAmount %s", user.amount);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
            if (pending > 0) {
                safeGoldenPearlTransfer( address(msg.sender), pending );
               // goldenPearl.safeTransfer(address(msg.sender), pending);
            }
        }

        if (_amount > 0) {
            uint256 amount_old = user.amount;

            user.amount = user.amount.add(_amount);

            stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);

            // set new locked amount based on average locking window
            uint256 lockedFor = blocksToUnlock(msg.sender);
            // avg lockedFor: (lockedFor * amount_old + blocks_locked * _amount) / user.amount
            lockedFor = lockedFor.mul(amount_old).add(blocks_locked.mul(_amount)).div(user.amount);
            // set new locked at 
            user.lockedAt = block.number.sub(blocks_locked.sub(lockedFor));
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR);

        emit Deposit(msg.sender, _amount);
    }

    function _correctUserAmountAccordingToLastBurn(UserInfo storage user) internal {
            if (user.amount > 0) {
                user.amount = _getUserAmountAfterBurn(user);
                user.rewardDebt = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR);
                // reduce to the amount from users last burn block to the offical last burn block
               /* uint256 burnEvents = (block.number - user.lastUserBurnBlock).div(burnBlockQuota); //.mul(burnMultiplier);

                uint256 _amount = user.amount.mul(PRECISION_FACTOR);
                for(uint256 current = 0; current < burnEvents; current++) {
                    _amount = _amount.mul(98).div(100);
                }
                uint256 amountAfterBurn = _amount.div(PRECISION_FACTOR);
                user.amount = amountAfterBurn; */
            }
            user.lastUserBurnBlock = lastBurnBlock;
    }

    function _getUserAmountAfterBurn(UserInfo storage user) internal view returns (uint256) {
        uint256 burnEvents = (block.number - user.lastUserBurnBlock).div(burnBlockQuota); //.mul(burnMultiplier);

        uint256 _amount = user.amount.mul(PRECISION_FACTOR);
        for(uint256 current = 0; current < burnEvents; current++) {
            _amount = _amount.mul(98).div(100);
        }
        return _amount.div(PRECISION_FACTOR);
    }
   
    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     * TODO since we burning stakedtokens the user only gets his percentage of tokens not the absolute amount
     */
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(blocksToUnlock(msg.sender) == 0, "Your Tokens still locked you cannot withdraw yet.");

        // Calc new user amount depending on lastBurnedBlock from user
        _correctUserAmountAccordingToLastBurn(user);
        _burnStakedTokens();

        require(user.amount >= _amount, "Amount to withdraw too high");

        _updatePool();

        console.log("WITHDRAW userAmount %s", user.amount);
        uint256 pending = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
 
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            stakedToken.safeTransfer(address(msg.sender), _amount);
        }

        if (pending > 0) {
            console.log("Withdraw pending gp %s", pending);
            console.log("Withdraw balanceOf gp %s", goldenPearl.balanceOf(address(this)));
            safeGoldenPearlTransfer(address(msg.sender), pending);
            // goldenPearl.safeTransfer(address(msg.sender), pending);
        }

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR);

        emit Withdraw(msg.sender, _amount);
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        _correctUserAmountAccordingToLastBurn(user);

        uint256 amountToTransfer = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        if (amountToTransfer > 0) {
            stakedToken.safeTransfer(address(msg.sender), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amount);
    }


    function getUserInfo(address _user) external view returns (uint256 amount, uint256 rewardDebt, 
                        uint256 lockedAt, uint256 lastUserBurnBlock) {
         UserInfo storage user = userInfo[_user];

         // Get amount with burnRate
       /* uint256 burnEvents = (block.number - user.lastUserBurnBlock).div(burnBlockQuota); //.mul(burnMultiplier);

        uint256 _amount = user.amount.mul(PRECISION_FACTOR);
        for(uint256 current = 0; current < burnEvents; current++) {
            _amount = _amount.mul(98).div(100);
        }
        uint256 amountAfterBurn = _amount.div(PRECISION_FACTOR); */
        uint256 amountAfterBurn = _getUserAmountAfterBurn(user);

        return ( amountAfterBurn, // (1e18 ** burnEvents), 
        user.rewardDebt, user.lockedAt, user.lastUserBurnBlock);
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

        uint256 _userAmount = user.amount > 0 ? _getUserAmountAfterBurn(user) : 0;
        uint256 _rewardDebt = _userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR);

        console.log("PENDING REWARD VIEW: %s %s", _userAmount, _rewardDebt);

        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            MonthlyReward memory fromSlice = getMonthlyReward(lastRewardBlock);
            MonthlyReward memory toSlice = getMonthlyReward(block.number);

            uint256 gpReward = _rewardForSlices(fromSlice, toSlice);
            uint256 adjustedTokenPerShare =
                accTokenPerShare.add(gpReward.mul(PRECISION_FACTOR).div(stakedTokenSupply));
            console.log("GP REWARD PENDING REWARD VIEW: %s", gpReward);
            return _userAmount.mul(adjustedTokenPerShare).div(PRECISION_FACTOR).sub(_rewardDebt);
        } else {
            return _userAmount.mul(accTokenPerShare).div(PRECISION_FACTOR).sub(_rewardDebt);
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

        uint256 burnEvents = (block.number - lastBurnBlock).div(burnBlockQuota); //.mul(burnMultiplier);
        console.log("BLOCKNUMBER %s, LAST BURN BLOCK %s", block.number, lastBurnBlock);
        console.log("BURNEVENTS: %s", burnEvents);

        uint256 _amount = stakedTokenSupply.mul(PRECISION_FACTOR);
        for(uint256 current = 0; current < burnEvents; current++) {
            _amount = _amount.mul(98).div(100);
        }
        uint256 amountAfterBurn = _amount.div(PRECISION_FACTOR);

        console.log("TOTAL SUPPLY AFTER BURN %s", amountAfterBurn);

        //uint256 amountAfterBurn = stakedTokenSupply * ( 1e18 - (2e18 / 100 )) ** burnEvents;
        uint256 pendingBurnAmount = stakedTokenSupply.sub(amountAfterBurn);
        console.log("PENDING BURN AMOUNT %s", pendingBurnAmount);

        //.div(1000).mul(2); // burn 2% of every 1000th block; Fixpoint: 0.02 * 100 = 2
       // uint256 burnAmount = stakedTokenSupply.mul(burnRatio).div(100);  // correct by 100

        if (pendingBurnAmount > 0) {
            stakedToken.safeTransfer(BURNING_ADDRESS, pendingBurnAmount);

            lastBurnBlock = block.number; 

            totalBurnedPearl = totalBurnedPearl.add(pendingBurnAmount);

            emit BurnStakedToken(pendingBurnAmount); 
        }
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

    // Safe GoldenPearl transfer function, just in case if rounding error causes pool to not have enough GoldenPearls.
    function safeGoldenPearlTransfer(address _to, uint256 _amount) internal {
        uint256 gpBal = goldenPearl.balanceOf(address(this));
        if (_amount > gpBal) {
            goldenPearl.safeTransfer(_to, gpBal);
        } else {
            goldenPearl.safeTransfer(_to, _amount);
        }
    }

    
    function updateBurnMultiplier(uint256 _burnMultiplier) public onlyOwner {
        burnMultiplier = _burnMultiplier;
        emit UpdateBurnMultiplier(msg.sender, _burnMultiplier);
    }

    function updateBurnBlockQuota(uint256 _blockQuota) public onlyOwner {
        burnBlockQuota = _blockQuota;
        emit UpdateBurnBlockQuota(msg.sender, _blockQuota);
    }

    function updateBlocksLocked(uint32 _blocks_locked) public onlyOwner {
        blocks_locked = _blocks_locked;
    }


    function blocksToUnlock(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _block_required = user.lockedAt.add(blocks_locked);
        if (_block_required <= block.number)
            return 0;
        else
            return _block_required.sub(block.number);
    }

}