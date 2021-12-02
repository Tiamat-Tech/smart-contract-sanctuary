/**
 *Submitted for verification at Etherscan.io on 2021-12-02
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.7;

contract VendingMachine {

    // Declare state variables of the contract
    address public owner;
    uint256 public cupcakeBalances;

    // When 'VendingMachine' contract is deployed:
    // 1. set the deploying address as the owner of the contract
    // 2. set the deployed smart contract's cupcake balance to 100
    constructor() {
        owner = msg.sender;
        cupcakeBalances = 100;
    }

    // Allow the owner to increase the smart contract's cupcake balance
    function refill(uint nrOfCupCakes) public {
        require(msg.sender == owner, "Only the owner can refill.");
        cupcakeBalances += nrOfCupCakes;
    }

    // Allow anyone to purchase cupcakes
    function purchase(uint nrOfCupCakes) public payable {
        require(msg.value >= nrOfCupCakes * 0.01 ether, "You must pay at least 0.01 ETH per cupcake");
        require(cupcakeBalances >= nrOfCupCakes, "Not enough cupcakes in stock to complete this purchase");
        cupcakeBalances -= nrOfCupCakes;
    }
}