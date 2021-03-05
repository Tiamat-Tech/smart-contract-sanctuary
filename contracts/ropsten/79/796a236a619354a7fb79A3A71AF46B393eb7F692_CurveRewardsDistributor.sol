pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "./ICurveRewards.sol";
import "./Owned.sol";

contract CurveRewardsDistributor is Owned {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public rewardPool;
    address constant private rewardToken = 0x25eB65f85A7f1ca4E9C5169D6E4b04C0ecF000F4;

    function initialize(address _owner, address _rewardPool) public {
        Owned.initialize(_owner);
        rewardPool = _rewardPool;
    }

    function distributeReward(uint256 amount) external onlyOwner {
        IERC20Upgradeable(rewardToken).safeTransferFrom(msg.sender, rewardPool, amount);
        ICurveRewards(rewardPool).notifyRewardAmount(amount);
    }
}