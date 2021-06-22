// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    function getStakedAmount() external view returns(uint256);
    function getAccountInfo(address staker) external view returns (uint256, uint256, uint256);
}