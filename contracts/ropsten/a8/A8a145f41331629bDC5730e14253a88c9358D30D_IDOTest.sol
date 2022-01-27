// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../ido/IDO.sol";

contract IDOTest is IDO {
    constructor(
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        ERC20 _USDTAddress, // solhint-disable-line var-name-mixedcase
        ERC20 _USDCAddress, // solhint-disable-line var-name-mixedcase
        uint256 _startTime,
        uint256 _endTime,
        uint256 _claimTime,
        uint256 _maxReward,
        uint256 _maxDistribution,
        address _treasury
    )
        IDO(
            _tokenPrice,
            _rewardToken,
            _USDTAddress,
            _USDCAddress,
            _startTime,
            _endTime,
            _claimTime,
            _maxReward,
            _maxDistribution,
            _treasury
        )
    {} // solhint-disable-line no-empty-blocks

    function testResetUser(address _user) external {
        UserInfo storage user = userInfo[_user];

        user.reward = 0;
        user.withdrawn = 0;
    }

    function testSetContractDistribution(uint256 _distribution) external {
        currentDistributed = _distribution;
    }

    function testBeforeStart() external {
        startTime = block.timestamp + 900;
        endTime = block.timestamp + 1800;
        claimTime = block.timestamp + 2100;
    }

    function testInProgress() external {
        startTime = block.timestamp - 300;
        endTime = block.timestamp + 900;
        claimTime = block.timestamp + 2100;
    }

    function testEndedNotClaimable() external {
        startTime = block.timestamp - 600;
        endTime = block.timestamp - 300;
        claimTime = block.timestamp + 900;
    }

    function testSetTimestamps(
        uint256 start,
        uint256 end,
        uint256 claim
    ) external {
        startTime = start;
        endTime = end;
        claimTime = claim;
    }

    function testClaimable() external {
        startTime = block.timestamp - 600;
        endTime = block.timestamp - 300;
        claimTime = block.timestamp;
    }

    function testFinishVesting() external {
        startTime = block.timestamp - 602 days;
        endTime = block.timestamp - 601 days;
        claimTime = block.timestamp - 600 days;
    }

    function testResetContract() external {
        currentDistributed = 0;
    }

    function testAddWhitelisted(address user) external {
        whitelisted[user] = true;
    }

    function testRemoveWhitelisted(address user) external {
        whitelisted[user] = false;
    }

    function testSetUserReward(address _user) external {
        UserInfo storage user = userInfo[_user];

        user.reward = 10000;
        user.withdrawn = 0;
    }
}