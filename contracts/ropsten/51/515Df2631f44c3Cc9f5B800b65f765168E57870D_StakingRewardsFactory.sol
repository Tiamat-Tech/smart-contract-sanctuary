// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import './StakingRewards.sol';

contract StakingRewardsFactory is Ownable {
    IERC20 immutable public rewardsToken;
    IERC20[] public stakingTokens;
    mapping(IERC20 => address) public stakingRewardsByStakingToken;

    constructor(address _owner, IERC20 _rewardsToken) {
        transferOwnership(_owner);
        rewardsToken = _rewardsToken;
    }

    function deploy(IERC20 stakingToken) public onlyOwner {
        require(stakingRewardsByStakingToken[stakingToken] == address(0), 'Already deployed');

        address stakingRewards = address(new StakingRewards(msg.sender, rewardsToken, stakingToken));
        stakingRewardsByStakingToken[stakingToken] = stakingRewards;
        stakingTokens.push(stakingToken);
    }

    function getStakingTokens() public view returns(IERC20[] memory) {
        return stakingTokens;
    }
}