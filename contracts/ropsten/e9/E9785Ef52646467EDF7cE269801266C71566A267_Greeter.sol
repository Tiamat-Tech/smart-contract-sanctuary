//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    uint private numParticipants;
    uint private cohort;
    uint private round;
    mapping (address => uint) public roundEliminated;
    uint[] private players;

    constructor() {
        console.log("Beginning Squid Games!");
        numParticipants = 4;
        cohort = 1;
        round = 1;
        // how do we hold ETH?
    }

    function register(uint number) public {
        // number must be between 1 and 100
        // add user to players
        // collect ETH from player
        // Do not allow more players than numParticipants
        // emit registration event
    }

    function executeRound() public {
        // Admin function
        // group remaining players
        // call generateRandomNumber()
        // Eliminate players in each group
        // Increase round
        // emit round over event
    }

    function endCohort() public {
        // Admin function
        // pay ETH
        // Reset round
        // Increase cohort
        // emit cohort over event
    }

    function generateRandomNumber() private returns (uint) {
        // generate random number between 1 and 100
    }

    function isPlayerEliminated(address a) private returns (bool) {
        // return true or false if player is eliminated
    }

}