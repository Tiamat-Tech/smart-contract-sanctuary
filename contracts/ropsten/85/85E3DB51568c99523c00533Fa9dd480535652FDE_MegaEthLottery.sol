//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

/// The MegaEthLottery Implements a lottery where a random number is picked, should a player have played that number,
/// they win the total jackpot.  If the winning number has been unplayed, the jackpot rolls to the next epoch.
contract MegaEthLottery {
    /// the winning_number for the current epoch
    int public winning_number;

    /// winning addresses
    mapping(address => bool) public winners;

    /// number of winners
    int public numWinners = 0;

    /// A map of entrants to how much they put into the lottery
    mapping(uint => mapping(int => address[])) lottoEntrants;

    /// Minimum buy-in to partake in the lottery
    uint256 public constant TICKET_PRICE = 0.01 ether;

    /// Duration of lottery
    uint public constant LOTTO_DURATION = 900;

    /// Maximum number to choose in lottery
    uint32 public constant NUM_CHOICES = 10000000;

    /// Winner Payout Ratio
    uint public constant PAYOUT_RATIO = 95;

    /// When the lottery ends
    uint public lottoEndTime;

    /// Total amount taken in this lottery
    uint public totalLottoAmount;

    /// The lottery has not finished running yet
    error LottoNotFinished();

    /// The lottery has ended
    error LottoAlreadyEnded();

    /// Need to pay more to enter lottery
    error NotEnoughFunds();

    /// You are not the winner
    error NotAWinner();

    /// Not a Playable number
    error NotAPlayableNumber();

    // Events that will be emitted on changes.
    event LottoParticipantAdded(address bidder, uint amount);
    event PrizeClaimed(address winner, uint amount);
    event PickingWinner();

    uint private epoch;

    /// Create a simple Lottery with `lottoDuration`
    /// seconds until a winner is announced
    constructor() {
        lottoEndTime = block.timestamp + LOTTO_DURATION;
    }

    /// Play the lottery with the value sent together with this transaction
    function playLottery(int32 number) external payable {
        if (block.timestamp > lottoEndTime)
            revert LottoAlreadyEnded();

        if (msg.value < TICKET_PRICE)
            revert NotEnoughFunds();

        if (number < 0 || uint32(number) > NUM_CHOICES)
            revert NotAPlayableNumber();

        lottoEntrants[epoch][number].push(msg.sender);
        totalLottoAmount += msg.value;

        emit LottoParticipantAdded(msg.sender, msg.value);
    }

    /// Declares the winner
    function declareWinner() public {
        if (block.timestamp < lottoEndTime)
            revert LottoNotFinished();
        emit PickingWinner();
        winning_number = 42;  // TODO: random
        address[] memory arr = lottoEntrants[epoch][winning_number];
        if (arr.length != 0) {
            for (uint i = 0; i < arr.length; i++) {
                winners[arr[i]] = true;
            }
            numWinners = int(arr.length);
        } else {
            lottoEndTime = block.timestamp + LOTTO_DURATION;
            winning_number = -1;
            epoch += 1;
        }
    }

    /// Claim the lottery prize if you are the winner
    function claimPrize() public {
        if (!winners[msg.sender])
            revert NotAWinner();

        emit PrizeClaimed(msg.sender, totalLottoAmount);

        uint prizeToTransfer = (totalLottoAmount / uint(numWinners)) * (PAYOUT_RATIO / 100);

        payable(msg.sender).transfer(prizeToTransfer);
    }
}