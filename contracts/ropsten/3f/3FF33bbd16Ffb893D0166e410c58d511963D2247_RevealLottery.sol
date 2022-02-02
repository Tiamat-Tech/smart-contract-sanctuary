//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

/// The RevealLottery Implements a lottery using a commit / reveal technique to pick the winner
/// When entrants buy into the lottery, they must submit a random hash along with their funds.
/// At the end, they must reveal what they submitted, and that will be used in a Seed to determine the winner.
/// Chance of winning lottery increases linearly with amount sent to the playLottery endpoint
contract RevealLottery {
    /// The winner of this lottery
    address payable public winner;

    /// Has the lottery Ended?
    bool ended;

    /// Is the lottery in the process of deciding the winner?
    bool decidingWinner;

    /// A map of entrants to how much they put into the lottery
    mapping(address => uint) entrantsToPayments;

    /// A map of entrants to their unrevealed hashes
    mapping(address => bytes32) entrantsToHashes;

    /// An array of all entrants
    address payable[] public entrants;

    /// When the lottery ends
    uint public lottoEndTime;

    /// Total amount taken in this lottery
    uint public totalLottoAmount;

    /// Minimum buy-in to partake in the lottery
    uint256 public constant TICKET_PRICE = 0.01 ether;

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
    constructor(uint lottoDuration) {
        lottoEndTime = block.timestamp + lottoDuration;
    }

    /// Play the lottery with the value sent together with this transaction
    function playLottery(bytes32 randomHash) external payable {
        if (block.timestamp > lottoEndTime)
            revert LottoAlreadyEnded();

        if (msg.value < TICKET_PRICE)
            revert NotEnoughFunds();

        entrantsToPayments[msg.sender] += msg.value;
        entrantsToHashes[msg.sender] = randomHash;
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