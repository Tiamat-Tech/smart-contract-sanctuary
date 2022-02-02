//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract CoinGames {
    uint public numParticipants;
    uint public cohort;
    uint public round;
    address public winner;
    mapping (address => uint) public roundEliminated;
    mapping (address => uint) public guesses;
    address[] public players;

    constructor() {
        console.log("Beginning Squid Games!");
        numParticipants = 4;
        cohort = 1;
        round = 1;
        // how do we hold ETH?
    }

    // Zach
    function register(uint number) public {
        require(number >= 1, "Number must be between 1 and 100");
        require(number <= 100, "Number must be between 1 and 100");

        require(players.length < numParticipants, "Game is full");

        uint existingGuess = guesses[msg.sender];
        require(existingGuess == 0, "Cannot guess twice");
        // User cannot pick same number as someone else?
        // Other validations?

        guesses[msg.sender] = number;
        players.push(msg.sender);

        // collect ETH from player
        // emit registration event
    }

    // Wanjia
    function executeRound() public {
        // Admin function
        // group remainingPlayers()
        // call generateRandomNumber()
        // Eliminate players in each group (use guesses for numbers; add to roundEliminated)
        // Increase round
        // endCohort() if only 1 remaining player
        // emit round over event
    }

    // Akshi
    function endCohort() public {
        // set winner
        // pay ETH to winner
        // emit cohort over event
    }

    // Victor
    function startNewCohort() public {
        // Admin function
        // Increase cohort
        // Reset round
        // clear players
    }

    // Victor
    function generateRandomNumber() private returns (uint) {
        // generate random number between 1 and 100
    }

    function isPlayerEliminated(address a) private returns (bool) {
        // return true or false if player is eliminated
    }

    // NOTE: need to return uint[] of players instead of bool
    function remainingPlayers() private returns (bool) {
        // filter players and only return ones who isPlayerEliminated() = false
    }

    // To be implemented
    // modifier isAdmin() {
    //
    // }

    // NOTE: flag functions that handle money / return data
}