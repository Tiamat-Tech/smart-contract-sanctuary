//SPDX-License-Identifier: UNLICENSED

// use memory in method if possible

// When deploying contracts, you should use the latest released version of Solidity. 
pragma solidity ^0.7.0;

// We import this library to be able to use console.log
import "hardhat/console.sol";

contract Token {
    string public name = "My Hardhat Token";
    string public symbol = "MHT";

    uint256 public totalSupply = 1000000;

    address public owner;

    mapping(address => uint256) balances;

    /**
     * The `constructor` is executed only once when the contract is created.
     */
    constructor() {
        // The totalSupply is assigned to transaction sender, which is the account
        // that is deploying the contract.
        balances[msg.sender] = totalSupply;
        owner = msg.sender;
    }

    /**
     * A function to transfer tokens.
     *
     * The `external` modifier makes a function *only* callable from outside
     * the contract.
     */
    function transfer(address to, uint256 amount) external {
        // If `require`'s first argument evaluates to `false` then the
        // transaction will revert.
        require(balances[msg.sender] >= amount, "Not enough tokens");

        console.log(
            "Transferring from %s to %s %s tokens",
            msg.sender,
            to,
            amount
        );

        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    /**
     * The `view` modifier indicates that it doesn't modify the contract's
     * state, which allows us to call it without executing a transaction.
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}