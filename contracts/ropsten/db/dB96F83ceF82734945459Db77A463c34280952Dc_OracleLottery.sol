//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

/// The OracleLottery Implements a lottery using an oracle to generate a random number and pick the winner
/// Chance of winning lottery increases linearly with amount sent to the playLottery endpoint
contract OracleLottery {
    /// The winner of this lottery
    address payable public winner;

    /// Has the lottery Ended?
    bool ended;

    /// Is the lottery in the process of deciding the winner?
    bool decidingWinner;

    /// A map of entrants to how much they put into the lottery
    mapping(address => uint) entrantsToPayments;

    /// An array of all entrants
    address payable[] public entrants;

    /// Minimum buy-in to partake in the lottery
    uint256 public constant TICKET_PRICE = 0.01 ether;

    /// Duration of lottery
    uint public constant LOTTO_DURATION = 450;

    /// When the lottery ends
    uint public lottoEndTime;

    /// Total amount taken in this lottery
    uint public totalLottoAmount;

    /// The function lottoEnd has already been called.
    error LottoEndAlreadyCalled();

    /// The lottery has ended
    error LottoAlreadyEnded();

    /// Need to pay more to enter lottery
    error NotEnoughFunds();

    /// You are not the winner
    error NotAWinner();

    // Events that will be emitted on changes.
    event LottoParticipantAdded(address bidder, uint amount);
    event PrizeClaimed(address winner, uint amount);
    event PickingWinner();

    /// Create a simple Lottery with `lottoDuration`
    /// seconds until a winner is announced
    constructor() {
        lottoEndTime = block.timestamp + LOTTO_DURATION;
    }

    /// Play the lottery with the value sent together with this transaction
    function playLottery() external payable {
        if (decidingWinner)
            revert LottoAlreadyEnded();

        if (block.timestamp > lottoEndTime)
            declareWinner();

        if (msg.value < TICKET_PRICE)
            revert NotEnoughFunds();

        entrantsToPayments[msg.sender] += msg.value;
        entrants.push(payable(msg.sender));
        totalLottoAmount += msg.value;

        emit LottoParticipantAdded(msg.sender, msg.value);
    }

    /// Declares the winner
    function declareWinner() public {
        decidingWinner = true;
        emit PickingWinner();
        winner = entrants[0];
    }

    /// Claim the lottery prize if you are the winner
    function claimPrize() public {
        if (msg.sender != winner)
            revert NotAWinner();

        emit PrizeClaimed(msg.sender, totalLottoAmount);

        winner.transfer(totalLottoAmount);
    }
}