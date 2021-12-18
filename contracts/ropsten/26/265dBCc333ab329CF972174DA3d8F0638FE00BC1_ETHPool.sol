// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ETHPool is Ownable, ReentrancyGuard {
    using Address for address payable;

    // balances
    mapping(address => uint256) public balances;

    uint256 public totalDeposited;

    // Members
    address[] public members;

    // Events
    event Deposit(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    constructor() {
        totalDeposited = 0;
    }

    function calculatePercentage(uint256 memberAmount, uint256 depositedAmount)
        public
        view
        returns (uint256)
    {
        return (memberAmount * depositedAmount) / totalDeposited;
    }

    function memberDeposit() external payable {
        address depositor = msg.sender;
        uint256 amount = msg.value;

        totalDeposited = totalDeposited + amount;

        balances[depositor] = balances[depositor] + amount;

        members.push(depositor);

        emit Deposit(depositor, amount);
    }

    function teamDeposit() external payable onlyOwner {
        require(totalDeposited > 0, "There are no deposits");

        uint256 amount = msg.value;

        for (uint256 j = 0; j < members.length; j++) {
            address member = members[j];

            uint256 memberDeposits = balances[member];
            uint256 memberAmount = calculatePercentage(amount, memberDeposits);
            balances[member] = balances[member] + memberAmount;
        }

        totalDeposited = totalDeposited + amount;

        emit Deposit(msg.sender, amount);
    }

    // Withdraw funds
    function withdraw() external nonReentrant {
        address receiver = msg.sender;

        uint256 amount = balances[receiver];
        payable(receiver).sendValue(amount);

        balances[receiver] = 0;

        totalDeposited = totalDeposited - amount;

        emit Withdraw(receiver, amount);
    }
}