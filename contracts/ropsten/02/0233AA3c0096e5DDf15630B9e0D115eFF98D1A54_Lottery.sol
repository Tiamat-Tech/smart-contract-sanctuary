//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Lottery {
    int private numPlays;
    address payable public winner;
    bool ended;
    mapping(address => uint) entrants;
    address[] public players;

    /// The function auctionEnd has already been called.
    error LottoEndAlreadyCalled();

    constructor(address payable winnerAddress) {
        winner = winnerAddress;
    }

    function playLottery() external payable {
        numPlays++;
        entrants[msg.sender] += msg.value;
        players.push(msg.sender);
        if (numPlays >= 5)
            endLottery();
    }

    function endLottery() public {
        if (ended)
            revert LottoEndAlreadyCalled();
        ended = true;
        for (uint i = 0; i <= players.length; i++) {
            winner.transfer(entrants[players[i]]);
        }
    }
}