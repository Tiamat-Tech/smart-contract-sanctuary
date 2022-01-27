/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

pragma solidity ^0.8.0;

contract TestContract {

    uint256 public multiplier;

    event SetMultiplier(uint256 multiplier);

    function multiply(uint256 multiplicand) external view returns (uint256) {
        return multiplicand * multiplier;
    }

    function setMultiplier(uint256 newMultiplier) external {
        multiplier = newMultiplier;
        emit SetMultiplier(newMultiplier);
    }
}