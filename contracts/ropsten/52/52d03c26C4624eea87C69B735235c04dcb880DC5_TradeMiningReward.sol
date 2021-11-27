//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/Ownable.sol";
//npm install @openzeppelin/contracts
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//npm add @uniswap/v3-periphery
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "hardhat/console.sol";

// Uniswap v3 interface
interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

// Add deposit function for WETH
interface DepositableERC20 is IERC20 {
    function deposit() external payable;
}

contract TradeMiningReward is Ownable {
    //address public daiAddress = 0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa; // replace pendle address
    //address public wethAddress = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    //address public uinswapV3QuoterAddress = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    //address public uinswapV3RouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    using SafeERC20 for IERC20;
    using SafeERC20 for DepositableERC20;
    using SafeMath for uint256;

    uint256 private rewardPerc;
    uint256 public stakeTarget;
    uint256 public txGasUnit;
    uint256 public gasFee;
    uint256 public timePeriod = 4 seconds; // set to 2 weeks, 4 sec for debugging
    //uint public ethPrice = 0;

    //IERC20 daiToken = IERC20(daiAddress);
    //DepositableERC20 wethToken = DepositableERC20(wethAddress);
    //IQuoter quoter = IQuoter(uinswapV3QuoterAddress);
    //IUniswapRouter uniswapRouter = IUniswapRouter (uinswapV3RouterAddress);

    // fix gasFee to  discourage frontrunning, if user set high gasfee and expect return from it also swap gas used is quite predictable
    //indexed for external to search for specific address event

    event AllocateAmount(uint256 amount);
    event ClaimAmount(uint256 amount);
    mapping(address => uint256) public lockedRewards; // locked allocated reward
    mapping(address => uint256) public unlockedRewards; // collectable reward
    mapping(address => uint256) public nextClaimDate; // track whether user claimed when unlocked

    constructor() {
        rewardPerc = 40; //set to 40%, 1 = 1%
        txGasUnit = 46666666666666; //(estimated gas used) avg transaction fee about 0.007 ether = 0.007e18 wei, assuming avg gas price is 150 wei then it is 46,666,666,666,667 gas used
        stakeTarget = 2000;
    }

    //initial plan estimate all wei to pendle value and store it as pendle value, but it will be decimal

    /* ----------------------------------imitate function (this function should in other contract)------------------------------------------*/
    function swap(
        address from,
        uint256 stakePerc,
        uint256 gasPrice
    ) public {
        //imitate swap function
        //do magic swap
        Claim(from);
        allocateRewards(from, stakePerc, gasPrice); // allocate reward
    }

    /* ----------------------------------Main function------------------------------------------*/
    function claimRewardsV2(address from) public {
        // imitate function claimRewards
        Claim(from);
        uint256 amount = getUnlockedBalance(from).div(1000000 wei);
        require(amount > 0, "Nothing to claim");
        clearUnlockReward(from);
        emit ClaimAmount(amount);
    }

    function Claim(address from) internal {
        //user will call this function to claim all their unlockRewards
        if (getClaimDate(from) <= block.timestamp) {
            // set new nextClaimDate & move lock to unlock
            lockToUnlock(from);
            setClaimDate(from);
        }
    }

    /* ----------------------------------External function------------------------------------------*/
    // should be external since swap from other contract will call this function
    function allocateRewards(
        address from,
        uint256 stakePerc,
        uint256 gasPrice
    ) internal {
        // gas fee * (basic + stake), allocate locked rewards after swap function
        uint256 amount;
        uint256 totalPerc = rewardPerc;
        updateGasFee(gasPrice);
        if (getClaimDate(from) == 0) {
            // check is it new user then set time for new user
            setClaimDate(from);
        }
        require(getClaimDate(from) > 0, "Require allocate of claim date");
        if (stakePerc >= stakeTarget) {
            // if stake more than 2000 token
            totalPerc = rewardPerc.add(10); // basic + stake
        }
        require(totalPerc <= 100, "No more than 100%");
        amount = gasFee.mul(totalPerc).div(100); // (gasPrice * txGasUnit) * (basic + stake)
        lockedRewards[from] = lockedRewards[from].add(amount); // value stored in wei
        emit AllocateAmount(amount);
    }

    /* ----------------------------------Should be internal function, set to public for testing purpose------------------------------------------*/

    // should be internal only called by claim
    function lockToUnlock(address from) internal {
        // allocate all lock to unlock, change to external if swap() is moved out
        require(getClaimDate(from) < block.timestamp, "Still not unlockable");
        require(lockedRewards[from] > 0, "Nothing to unlock");
        unlockedRewards[from] = unlockedRewards[from].add(lockedRewards[from]);
        lockedRewards[from] = 0; // reset to 0 value
    }

    // should be internal only called by claimRewards
    function clearUnlockReward(address from) internal {
        //reward claimed, set unlockedRewards to 0
        unlockedRewards[from] = 0;
        require(unlockedRewards[from] == 0, "Reward not cleaned up");
    }

    // should be internal only called when allocateRewards
    function updateGasFee(uint256 gasPrice) internal {
        require(gasPrice > 0, "gas Price > 0");
        gasFee = txGasUnit.mul(gasPrice);
    }

    function setClaimDate(address from) internal {
        // set next claimable date after claimed
        nextClaimDate[from] = block.timestamp.add(timePeriod);
    }

    /* ----------------------------------Only owner function------------------------------------------*/
    function setRewardPerc(uint256 newPerc) public onlyOwner {
        //only owner can set %
        require(newPerc <= 100, "No more than 100%");
        rewardPerc = newPerc;
    }

    function setTxGasUnit(uint256 newGas) public onlyOwner {
        txGasUnit = newGas;
    }

    function setStakeTarget(uint256 newLimit) public onlyOwner {
        stakeTarget = newLimit;
    }

    /* ----------------------------------All view function------------------------------------------*/

    function getRewardPerc() public view onlyOwner returns (uint256) {
        return rewardPerc;
    }

    function getLockedBalance(address from) public view returns (uint256) {
        return lockedRewards[from];
    }

    function getUnlockedBalance(address from) public view returns (uint256) {
        return unlockedRewards[from];
    }

    function getClaimDate(address from) public view returns (uint256) {
        return nextClaimDate[from];
    }

    receive() external payable {
        // accept ETH
    }
    //remove
    /*

    function getGasFee() public view returns(uint){
        return gasFee;
    }
    */

    /*
    function getWethBalance() public view returns(uint) {
        return wethToken.balanceOf(address(this));
    }
    function updateEthPriceUniswap() public returns(uint) {
        uint ethPriceRaw = quoter.quoteExactOutputSingle(daiAddress,wethAddress,3000,100000,0);
        ethPrice = ethPriceRaw / 100000;
        return ethPrice;
    }
    function claimRewards() public { // convert wei to pendle(dai)
        Claim();
        address recipient = address(this);
        uint256 deadline = block.timestamp.add(15);
        uint256 amountOut = getUnlockedBalance().div(1 ether);
        uint256 amountInMaximum = 10 ** 28 ;
        uint160 sqrtPriceLimitX96 = 0;
        uint24 fee = 3000;
        require(wethToken.approve(address(uinswapV3RouterAddress), amountOut), "WETH approve failed");
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams(
        wethAddress,
        daiAddress,
        fee,
        recipient,
        deadline,
        amountOut,
        amountInMaximum,
        sqrtPriceLimitX96
        );
        uniswapRouter.exactOutputSingle(params);
        uniswapRouter.refundETH();
        clearUnlockReward();
    }
    function wrapETH() public onlyOwner{
        uint ethBalance = address(this).balance; //address(this) is contract address
        require(ethBalance > 0, "No ETH available to wrap");
        emit Log("wrapETH", ethBalance);
        wethToken.deposit{ value: ethBalance }();
    }*/
}