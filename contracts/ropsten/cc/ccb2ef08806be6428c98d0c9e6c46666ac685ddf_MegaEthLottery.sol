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

    /// A map of lottery epoch to numbers selected by participants
    mapping(uint => mapping(int => address[])) lottoEntrants;

    /// A map of entrants to their sealed random shard.
    mapping(uint => mapping(address => bytes32)) entrantsToSealedRandomShards;

    /// Minimum buy-in to partake in the lottery
    uint256 public constant TICKET_PRICE = 0.01 ether;

    /// Duration of lottery commit phase
    uint public constant COMMIT_DURATION = 900;

    /// Duration of lottery reveal phase
    uint public constant REVEAL_DURATION = 900;

    /// Maximum number to choose in lottery
    uint32 public constant NUM_CHOICES = 10000000;

    /// Winner Payout Ratio
    uint public constant PAYOUT_RATIO = 95;

    /// When the lottery ends
    uint public commitEndTime;

    /// When the random shard reveal time ends
    uint public revealEndTime;

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

    bytes32 public randomSeed;

    /// Create a simple Lottery with `lottoDuration`
    /// seconds until a winner is announced
    constructor() {
        commitEndTime = block.timestamp + COMMIT_DURATION;
        revealEndTime = commitEndTime + REVEAL_DURATION;
    }

    /// Play the lottery with the value sent together with this transaction
    function playLottery(int32 number, bytes32 sealedRandomShard) external payable {
        if (block.timestamp > commitEndTime)
            revert LottoAlreadyEnded();

        if (msg.value < TICKET_PRICE)
            revert NotEnoughFunds();

        if (number < 0 || uint32(number) > NUM_CHOICES)
            revert NotAPlayableNumber();

        lottoEntrants[epoch][number].push(msg.sender);
        entrantsToSealedRandomShards[epoch][msg.sender] = sealedRandomShard;
        totalLottoAmount += msg.value;

        emit LottoParticipantAdded(msg.sender, msg.value);
    }

    /// (Optionally) Reveal the previously commited sealed random shard to contribute to the randomness of picking the winner
    function reveal(uint randomShard) public {
        require(block.timestamp > commitEndTime, "Still in commit phase.");
        require(block.timestamp <= revealEndTime, "Reveal phase closed.");

        bytes32 sealedRandomShard = seal(randomShard);
        require(
            sealedRandomShard == entrantsToSealedRandomShards[epoch][msg.sender],
            "Invalid Random Shard provided!"
        );

        randomSeed = keccak256(abi.encode(randomSeed, randomShard));
    }

    /// Declares the winner
    function declareWinner() public {
        if (block.timestamp < revealEndTime)
            revert LottoNotFinished();
        emit PickingWinner();
        winning_number = int(uint256(randomSeed) % NUM_CHOICES);
        address[] memory arr = lottoEntrants[epoch][winning_number];
        if (arr.length != 0) {
            for (uint i = 0; i < arr.length; i++) {
                winners[arr[i]] = true;
            }
            numWinners = int(arr.length);
        } else {
            commitEndTime = block.timestamp + COMMIT_DURATION;
            revealEndTime = commitEndTime + REVEAL_DURATION;
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

    /// Helper view function to seal a given randomShard
    function seal(uint256 randomShard) public view returns (bytes32) {
        return keccak256(abi.encode(msg.sender, randomShard));
    }
}