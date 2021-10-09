// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ETHPoolStorage.sol";
import "./IETHPool.sol";


contract ETHPool is ETHPoolStorage, IETHPool, Ownable {

    event UserDeposit(address indexed depositor, uint256 depositValue, uint256 sharesGiven);
    event UserWithdraw(address indexed depositor, uint256 withdrawValue, uint256 sharesTaken);
    event TeamAddressChanged(address newAddress);
    event RewardsDeposited(address team, uint256 rewardAmount);

    /**
     * @dev Check if the account is registered as the team.
     */
    modifier isTeamAccount {
        require(_msgSender() == teamAddress, "!TeamAccount");
        _;
    }

    /**
     * @dev Initialize this contract. Owner defaults in constructor to contract deployer.
     * Initialization should be preferred over constructor for compatibility with proxies & upgrades.
     * @param _teamAddress The ETH address of the team responsible for reward deposits.
     */
    function initialize(address _teamAddress) external onlyOwner {
        _setTeamAddress(_teamAddress);
    }

    /**
     * @dev Deposit funds into the pool, and recieve shares entitling the user to ETH from the reward pool.
     */
    function userDeposit() external payable override returns (uint256) {
        // Get the deposit data
        Depositor storage depositor = pool.depositors[_msgSender()];
        uint256 depositValue = msg.value;

        // Calculate & validate shares to issue
        uint256 shares = (pool.eth == 0) ? depositValue : ((depositValue * pool.shares) / pool.eth);
        require(shares > 0, "Shares !> 0");

        // Update the deposit pool and individual share ownership
        pool.eth += depositValue;
        pool.shares += shares;
        depositor.shares += shares;
        emit UserDeposit(_msgSender(), depositValue, shares);
        return shares;

    }

    /**
     * @dev Withdraw funds from the pool, based on the amount of available shares a user has.
     * @param _sharesToWithdraw The number of shares a user wishes to exchange for ETH in the reward pool. Stored as calldata.
     */
    function userWithdraw(uint256 _sharesToWithdraw) external override returns (uint256) {
        // Can only withdraw a non-zero amount of shares
        require(_sharesToWithdraw > 0, "Need >0 Shares");
        Depositor storage depositor = pool.depositors[_msgSender()];

        // Validate shares and calculate ETH return
        require(depositor.shares >= _sharesToWithdraw, "Not enough shares");
        uint256 eth = ((_sharesToWithdraw * pool.eth) / pool.shares);

        // Update the deposit pool and individual shares
        pool.eth -= eth;
        pool.shares -= _sharesToWithdraw;
        depositor.shares -= _sharesToWithdraw;

        // Withdraw the ETH, reverting on failure
        payable(_msgSender()).transfer(eth);
        emit UserWithdraw(_msgSender(), eth, _sharesToWithdraw);
        return eth;
    }

    /**
     * @dev Deposit ETH rewards into the pool. May only be called by the team account.
     */
    function depositRewards() external payable override isTeamAccount {
        pool.eth += msg.value;
        emit RewardsDeposited(_msgSender(), msg.value);
    }

    /**
     * @dev Set the team address. Private, used by the initilizer.
     * @param _address The ETH address to set the team address to.
     */
    function _setTeamAddress(address _address) private {
        teamAddress = _address;
        emit TeamAddressChanged(_address);
    }


    /**
    * @dev Get the number of shares owned by a user. Required here as a custom getter, as
    * Solidity does not auto-generate public getters for mappings inside structs.
    * See more here: https://docs.soliditylang.org/en/v0.8.9/contracts.html?highlight=public#getter-functions
    * @param _depositor The ETH address to get the shares for.
    */
    function getDepositedShares(address _depositor) external view returns (uint256) {
        return pool.depositors[_depositor].shares;
    }


}