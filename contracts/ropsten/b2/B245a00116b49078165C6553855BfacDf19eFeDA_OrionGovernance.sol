// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IOrionGovernance.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OrionGovernance is IOrionGovernance, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    struct UserData
    {
        uint56 balance;
        uint56 locked_balance;
    }

    ///////////////////////////////////////////////////
    //  Data fields
    //  NB: Only add new fields BELOW any fields in this section

    //  Must be 8-digit token
    IERC20 public staking_token_;

    //  Staking balances
    mapping(address => UserData) public balances_;

    //  Voting contract address (now just 1 voting contract supported)
    address public voting_contract_address_;

    //  Total balance
    uint56 public total_balance_;

    //  Add new data fields there....
    //      ...

    //  End of data fields
    /////////////////////////////////////////////////////

    //  Initializer
    function initialize(address staking_token) public payable initializer {
        OwnableUpgradeable.__Ownable_init();
        staking_token_ = IERC20(staking_token);
    }

    function setVotingContractAddress(address voting_contract_address) external onlyOwner
    {
        voting_contract_address_ = voting_contract_address;
    }

    //  Stake
    function stake(uint56 adding_amount) external nonReentrant
    {
        require(adding_amount > 0, "Cannot stake 0");
        staking_token_.safeTransferFrom(msg.sender, address(this), adding_amount);

        uint56 balance = balances_[msg.sender].balance;
        balance += adding_amount;
        require(balance >= adding_amount, "overflow(1)");
        balances_[msg.sender].balance = balance;

        uint56 total_balance = total_balance_;
        total_balance += adding_amount;
        require(total_balance >= adding_amount, "overflow(3)");  //  Maybe not needed
        total_balance_ = total_balance;
    }

    // Unstake
    function withdraw(uint56 removing_amount) external nonReentrant
    {
        require(removing_amount > 0, "Cannot withdraw 0");

        uint56 balance = balances_[msg.sender].balance;
        require(balance >= removing_amount, "Cannot withdraw");
        balance -= removing_amount;
        balances_[msg.sender].balance= balance;

        uint56 total_balance = total_balance_;
        require(total_balance >= removing_amount, "Cannot withdraw");
        total_balance -= removing_amount;
        total_balance_ = total_balance;

        uint56 locked_balance = balances_[msg.sender].locked_balance;
        require(locked_balance <= balance, "Cannot withdraw(2)");
        staking_token_.safeTransfer(msg.sender, removing_amount);
    }

    function acceptNewLockAmount(
        address user,
        uint56 new_lock_amount
    ) external override onlyVotingContract
    {
        uint56 balance = balances_[user].balance;
        require(balance >= new_lock_amount, "Cannot lock");
        balances_[user].locked_balance = new_lock_amount;
    }

    function acceptLock(
        address user,
        uint56 lock_increase_amount
    )  external override onlyVotingContract
    {
        require(lock_increase_amount > 0, "Can't inc by 0");

        uint56 balance = balances_[user].balance;
        uint56 locked_balance = balances_[user].locked_balance;

        locked_balance += lock_increase_amount;
        require(locked_balance >= lock_increase_amount, "overflow(4)");
        require(locked_balance <= balance, "can't lock more");

        balances_[user].locked_balance = locked_balance;
    }

    function acceptUnlock(
        address user,
        uint56 lock_decrease_amount
    )  external override onlyVotingContract
    {
        require(lock_decrease_amount > 0, "Can't dec by 0");

        uint56 locked_balance = balances_[user].locked_balance;
        require(locked_balance >= lock_decrease_amount, "Can't unlock more");

        locked_balance -= lock_decrease_amount;
        balances_[user].locked_balance = locked_balance;
    }

    //  Views
    function getBalance(address user) public view returns(uint56)
    {
        return balances_[user].balance;
    }

    function getLockedBalance(address user) public view returns(uint56)
    {
        return balances_[user].locked_balance;
    }

    function getTotalBalance() public view returns(uint56)
    {
        return total_balance_;
    }

    //  Modifiers
    modifier onlyVotingContract()
    {
        require(msg.sender == voting_contract_address_, "must be voting");
        _;
    }
}