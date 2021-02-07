// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./SafeMath.sol";

contract VestingVaultBatchRelease {

    using SafeMath for uint256;

    event ChangeBeneficiary(address oldBeneficiary, address newBeneficiary);

    event Withdraw(address indexed to, uint256 amount);

    string public name;

    address public vestingToken;

    uint256 public constant vestingPeriodUnit = 30 days;

    uint256 public constant vestingBatchs = 10;

    uint256 public immutable timeLockedVestedAmount;

    uint256 public vestingEndTimestamp;

    address public beneficiary;

    constructor (string memory name_, address vestingToken_, address beneficiary_, uint256 timeLockedVestedAmount_) {
        name = name_;
        vestingToken = vestingToken_;
        vestingEndTimestamp = block.timestamp + vestingPeriodUnit.mul(vestingBatchs);
        timeLockedVestedAmount = timeLockedVestedAmount_;
        beneficiary = beneficiary_;
    }

    function setBeneficiary(address newBeneficiary) public {
        require(msg.sender == beneficiary, "VestingVault.setBeneficiary: can only be called by beneficiary");
        emit ChangeBeneficiary(beneficiary, newBeneficiary);
        beneficiary = newBeneficiary;
    }

    function withdraw(address to, uint256 amount) public {
        require(msg.sender == beneficiary, "VestingVault.withdraw: can only be called by beneficiary");
        IToken(vestingToken).transfer(to, amount);

        uint256 currentTimestamp = block.timestamp;
        if (currentTimestamp < vestingEndTimestamp) {
            //release discretely on a "vestingPeriodUnit" basis (e.g. monthly basis if vestingPeriodUnit = 30 days)
            //after every vestingPeriodUnit, 1 vestingBatch (1/vestingBatchs of timeLockedVestedAmount) is released
            //ratio remaining locked = (1/vestingBatchs) * ((vestingEndTimestamp - currentTimestamp)/vestingPeriodUnit + 1)
            uint256 vested = vestingEndTimestamp.sub(currentTimestamp).div(vestingPeriodUnit).add(1).mul(timeLockedVestedAmount).div(vestingBatchs);
            uint256 balance = IToken(vestingToken).balanceOf(address(this));
            require(balance >= vested, "VestingVault.withdraw: amount exceeds allowed by schedule");
        }

        emit Withdraw(to, amount);
    }

}

interface IToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}