// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./interfaces/IStakingRewards.sol";


/// @author Conjure Team
/// @title ConjureRouter
/// @notice The ConjureRouter which distributes the conjure fees
contract ConjureRouter {

    // event for distribution
    event FeeDistribution(address treasury, address stakingrewards, uint256 amount);
    // event for new threshold
    event NewThreshold(uint256 value);

    IStakingRewards public stakingRewards;
    address payable public treasury;
    address public owner;
    uint256 public threshold = 0.1 ether;

    constructor(IStakingRewards _stakingRewards, address payable _treasury) {
        require(_treasury != address(0), "not zero address");
    
        stakingRewards = _stakingRewards;
        treasury = _treasury;
        owner = msg.sender;
    }

    /**
    * @notice distributes the fees if the balance is 0.1 or higher
    * sends 50% to the treasury
    * sends 50% to the staking rewards contract
    * calls notifyRewardAmount on the staking contract
    */
    function distribute() internal {
        uint256 amount = address(this).balance;

        if (amount > threshold) {
            emit FeeDistribution(treasury, address(stakingRewards), amount);
            
            treasury.transfer(amount / 2);
            payable(address(stakingRewards)).transfer(amount / 2);
            stakingRewards.notifyRewardAmount(amount / 2);
        }
    }

    /**
    * deposit function for collection funds
    * only executes the distribution logic if the contract balance is more than 0.1 ETH
    */
    function deposit() external payable {
        distribute();
    }

    /**
    * fallback function for collection funds
    * only executes the distribution logic if the contract balance is more than 0.1 ETH
    */
    fallback() external payable {
        distribute();
    }

    /**
    * fallback function for collection funds
    * only executes the distribution logic if the contract balance is more than 0.1 ETH
    */
    receive() external payable {
        distribute();
    }

    function newStakingrewards(IStakingRewards newRewards) external {
        require(msg.sender == owner, "Only owner");
        require(address(newRewards) != address(0), "not zero address");
        stakingRewards = newRewards;
    }

    function newTreasury(address payable newTreasuryAddress) external {
        require(msg.sender == owner, "Only owner");
        require(newTreasuryAddress != address(0), "not zero address");
        treasury = newTreasuryAddress;
    }

    function setNewOwner(address newOwner) external {
        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "not zero address");
        owner = newOwner;
    }

    function setNewThreshold(uint256 newthreshold) external {
        require(msg.sender == owner, "Only owner");
        threshold = newthreshold;
        emit NewThreshold(threshold);
    }
}