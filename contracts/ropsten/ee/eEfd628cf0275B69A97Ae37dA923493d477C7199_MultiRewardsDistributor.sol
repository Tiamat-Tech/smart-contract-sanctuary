pragma solidity >=0.6.0 <0.8.0;

interface IMultiRewards {
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external; 
}