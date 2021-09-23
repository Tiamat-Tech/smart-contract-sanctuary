pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./models/staking/StakingPool.sol";
import "./models/staking/StakingPoolCreate.sol";

contract Treasury is Ownable, ReentrancyGuard{
    mapping(string => StakingPool) public StakingPools;

    //Emitted when transferring tokens
    event TokensTransferred(string stakingPoolId, uint256 amount);
    event StakingPoolCreated(string stakingPoolId);
    event TokensWithdrawn(string stakingPoolId, uint256 amount);

    /**
     * @dev Create a staking pool
     * @param stakingPoolinfo the required info struct for creation
    */
    function CreateStakingPool(StakingPoolCreate memory stakingPoolinfo) nonReentrant external{
        require(!StakingPoolExists(stakingPoolinfo.StakingPoolId), "Stakingpool already exists!");
        require(stakingPoolinfo.Startdate > block.timestamp, "Stakingpool should start in the future");
        require(IERC20(stakingPoolinfo.TokenAddress).allowance(_msgSender(), address(this)) >= stakingPoolinfo.TokenAmount , "Allowance for token is not set");

        StakingPools[stakingPoolinfo.StakingPoolId].OwnerAddress = _msgSender();
        StakingPools[stakingPoolinfo.StakingPoolId].TokenAddress = stakingPoolinfo.TokenAddress;
        StakingPools[stakingPoolinfo.StakingPoolId].TokenAmount = stakingPoolinfo.TokenAmount;
        StakingPools[stakingPoolinfo.StakingPoolId].RemainingAmount = stakingPoolinfo.TokenAmount;
        StakingPools[stakingPoolinfo.StakingPoolId].Startdate = stakingPoolinfo.Startdate;
        StakingPools[stakingPoolinfo.StakingPoolId].Enddate = stakingPoolinfo.Enddate;
        StakingPools[stakingPoolinfo.StakingPoolId].VestingTime = stakingPoolinfo.VestingTime;
        StakingPools[stakingPoolinfo.StakingPoolId].VestingPercentage = stakingPoolinfo.VestingPercentage;
        StakingPools[stakingPoolinfo.StakingPoolId].IsVesting = stakingPoolinfo.VestingTime != 0 && stakingPoolinfo.VestingPercentage != 0;
        if(StakingPools[stakingPoolinfo.StakingPoolId].IsVesting)
        {
            uint nrOfPeriods = 100 / stakingPoolinfo.VestingPercentage;
            uint remainder = 100 % stakingPoolinfo.VestingPercentage;
            if(remainder > 0) nrOfPeriods += 1;
            StakingPools[stakingPoolinfo.StakingPoolId].Enddate = stakingPoolinfo.Startdate + (nrOfPeriods * (stakingPoolinfo.VestingTime * 1 days));
        }
        StakingPools[stakingPoolinfo.StakingPoolId].Exists = true;
        emit StakingPoolCreated(stakingPoolinfo.StakingPoolId);

        IERC20(stakingPoolinfo.TokenAddress).transferFrom(_msgSender(), address(this), stakingPoolinfo.TokenAmount);
        emit TokensTransferred(stakingPoolinfo.StakingPoolId, stakingPoolinfo.TokenAmount);
    }

    /**
     * @dev Withdraw stakingpool tokens (to distribute amongst charities)
     * @param stakingPoolId the id of the staking pool
    */
    function WithdrawStakingPool(string memory stakingPoolId) onlyOwner() nonReentrant external{
        require(StakingPoolExists(stakingPoolId), "Stakingpool does not exist!");
        require(StakingPools[stakingPoolId].RemainingAmount > 0, "No tokens remaining for withdrawal");
        require(StakingPools[stakingPoolId].Startdate < block.timestamp, "Staking pool has not started");
        if(!StakingPools[stakingPoolId].IsVesting){// not vesting -> release all
            require(StakingPools[stakingPoolId].Enddate < block.timestamp, "Staking pool has not finished");
            StakingPools[stakingPoolId].RemainingAmount = 0;
            IERC20(StakingPools[stakingPoolId].TokenAddress).transfer(_msgSender(), StakingPools[stakingPoolId].TokenAmount);
            emit TokensWithdrawn(stakingPoolId, StakingPools[stakingPoolId].TokenAmount);
        }else{
            uint256 claimed = StakingPools[stakingPoolId].TokenAmount - StakingPools[stakingPoolId].RemainingAmount;
            uint256 elapsed = block.timestamp - StakingPools[stakingPoolId].Startdate;
            uint256 releaseTimes = elapsed / (StakingPools[stakingPoolId].VestingTime * 1 days);
            require(releaseTimes > 0, "No interval available!");
            uint256 toRelease = (((StakingPools[stakingPoolId].TokenAmount / 100) * StakingPools[stakingPoolId].VestingPercentage) * releaseTimes) - claimed;
            require(toRelease > 0, "Interval already withdrawed");
            if(toRelease > StakingPools[stakingPoolId].RemainingAmount) toRelease = StakingPools[stakingPoolId].RemainingAmount;
            StakingPools[stakingPoolId].RemainingAmount -= toRelease;
            IERC20(StakingPools[stakingPoolId].TokenAddress).transfer(_msgSender(), toRelease);
            emit TokensWithdrawn(stakingPoolId, toRelease);
        }
    }

    /**
     * @dev Check to see if staking pool exists
     * @param stakingPoolId the id of the staking pool
    */
    function StakingPoolExists(string memory stakingPoolId) public view returns (bool){
        return StakingPools[stakingPoolId].Exists;
    }
}