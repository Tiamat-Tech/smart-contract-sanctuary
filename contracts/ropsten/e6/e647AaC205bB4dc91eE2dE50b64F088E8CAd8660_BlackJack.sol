// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Simple version of Black Jack. The player actions are hit and stand. Other
// options such as double down, split, and surrender are not implemented.
//
// Game play:
//
// It is each player against the house, players are not up against each
// other. The goal of the game is to have a higher score than the house
// while having a score that is less than or equal to 21. 21, Blackjack,
// is the best score.
//
// Players join the game by putting down chips (money). Those chips
// are then locked in the game during play. The house then deals themselves
// one card. Each player can then request to have their two cards.
// Now the player can stand, meaning they won't take more cards and
// are done. The other option is to hit, which means they get dealt another
// card. They can hit as much as they want until they either bust (over 21)
// or decide to stand. Once all players are done or the time limit has run
// out it is the house's turn. The house draws a single card at a time
// until they have a score that is greater than or equal to 17. At that
// point the results can be calculated. If the house has a higher score
// than a player the house gets their chips. If the house has a lower
// score than a player the player gets two times their amount of chips
// back. If the house ties a player the player gets just their chips
// back. If the house busts and a player doesn't the players wins. If
// the house does not bust and the player does the house wins. If both
// the house and the player bust the house wins.
//
// If the player wins or ties they can withdraw those funds for that round.
//
// Improvements:
// - Implement the full suite of player actions (double down, split, etc...)
// - The contract is close to the max size. Because of that I removed some
//   variables that make the code more readable. Instead, we could split
//   this functionality into multiple contracts or a contract and libraries.
//   The random card draws seems like a good candidate for a different
//   contract, which could then be updated as that code got improved.
// - The shuffle is deterministic. If someone really wanted to peak
//   ahead to what card they might draw to get an unfair advantage they could.
//   Move to something like chain.link that has verified random values.
// - There is no notion of a deck, the cards are entirely random on every draw.
//   Implement some sort of deck so there are N decks worth of cards where N
//   is a number based on the number of players.
// - Allow players to withdraw for the current round if the game hasn't started.

contract BlackJack is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint8;

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Enums & Structs.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    enum Card {
        Two,
        Three,
        Four,
        Five,
        Six,
        Seven,
        Eight,
        Nine,
        Ten,
        Jack,
        Queen,
        King,
        Ace
    }

    enum HandStatus {
        Inactive,
        Active,
        Stand,
        Bust
    }

    // The max amount of cards one could draw would be 21 aces in a game
    // where every draw is truly random.
    uint8 internal constant MAX_CARDS_PER_HAND = 21;

    // This represents data for a given player for a single round.
    struct Hand {
        Card[MAX_CARDS_PER_HAND] cards;
        HandStatus status;
        uint8 numberOfCards;
        uint8 score;
        uint256 deposit;
    }

    // This represents all metadata for a player (address) that has
    // participated in any round.
    struct Player {
        // The rounds (uints) that this player has participated in.
        uint256[] roundsPlayed;
        // For each round what was the hand that this player had.
        mapping(uint256 => Hand) roundToHand;
        // Which rounds has this player already withdrawn their money
        // for if they were owed anything.
        mapping(uint256 => bool) roundsWithdrawn;
    }

    event PlayerJoinedGame(uint256 round, address player);
    event GameStarted(uint256 round, uint256 roundEnd);
    event PlayerUpdate(
        uint256 round,
        address player,
        uint8 score,
        HandStatus status
    );
    event GameEnded(uint256 round);

    // The amount of money that is owed to players. Only allow players
    // to join if the house has enough money to accomodate them.
    uint256 public owedToPlayers = 0;
    // Min and max a player can bid. These can be adjusted by the owner.
    uint256 public minBid = 1;
    uint256 public maxBid = 1 ether;
    // If the game is underway.
    bool public gameStarted = false;
    // The current round or game number.
    // Used to track participants and winners across rounds.
    uint256 public round = 0;
    // The time players have to complete their turn before the house is
    // allowed to end the game. Otherwise, a player could never end their
    // turn, which would lock a lot of money in the game. After this
    // amount of time the house can end the round even if some players haven't gone yet.
    // If the house doesn't end the game the players can continue to
    // play even after the time.
    uint256 public roundLength = 5 minutes;
    // When the current round ends.
    uint256 public roundEnd;
    // Per round track the amount of players who are done to avoid iteration.
    uint256 public playersDone = 0;
    // Address to player.
    mapping(address => Player) internal addressToPlayer;
    // Who is currrently in each round.
    mapping(uint256 => address[]) public addressesInRound;
    // A hand object that represents the hand of the house in the round (index of array).
    Hand[] public roundToHouseHand;
    // A mapping from the round to the score to the amount deposited by players
    // in that round who ended the round with this score. This allows us to
    // end the round without having to iterate through all players.
    mapping(uint256 => mapping(uint256 => uint256))
        private roundToScoreToDeposit;

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Modifiers.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------

    // Only players with a specific status can do this.
    modifier onlyStatus(HandStatus status) {
        require(
            addressToPlayer[msg.sender].roundToHand[round].status == status,
            "Incorrect status"
        );
        _;
    }

    // Players with this status cannot do this.
    modifier notStatus(HandStatus status) {
        require(
            addressToPlayer[msg.sender].roundToHand[round].status != status,
            "Incorrect status"
        );
        _;
    }

    // The game needs to be going.
    modifier gameIsActive() {
        require(gameStarted == true, "Game must be started");
        _;
    }

    modifier gameIsInactive() {
        require(gameStarted == false, "Game is already going");
        _;
    }

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Main external game functions.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------

    // How players join the game. Only players who have the status of inactive are allowed to join.
    // If their status is not inactive they are already playing.
    function joinGame()
        external
        payable
        gameIsInactive
        onlyStatus(HandStatus.Inactive)
    {
        // The owner can't join the game.
        require(owner() != msg.sender, "Owner can't play");
        // Make sure they put in enough money for the round.
        require(msg.value >= minBid, "Insufficient bid");
        require(msg.value <= maxBid, "Over max bid");
        // Make sure the house has enough money to allow this player in. If the player wins we owe them the money
        // they just sent plus that amount from the house. So we need to have 2 times the amount of money
        // they sent to accomodate this player.
        require(
            address(this).balance >= (msg.value * 2) + owedToPlayers,
            "Insufficient funds"
        );
        owedToPlayers += (msg.value * 2);

        // Add the player to the game. Since an address could play in multiple rounds we need to
        // reset the data everytime they join a round. winCount is the exception to that. This
        // should accumulate across rounds.
        Player storage player = addressToPlayer[msg.sender];
        player.roundsPlayed.push(round);
        Hand storage hand = player.roundToHand[round];
        hand.status = HandStatus.Active;
        hand.deposit = msg.value;
        hand.numberOfCards = 0;
        addressesInRound[round].push(msg.sender);
        emit PlayerJoinedGame(round, msg.sender);
    }

    // Start the game. To avoid very high gas fees from doing an unbounded for loop only deal
    // to the house. The players can each run a function to get their initial cards for the round.
    function startGame() external onlyOwner gameIsInactive {
        // There needs to be at least one player.
        require(addressesInRound[round].length > 0, "Need players");
        require(roundToHouseHand.length == round, "FATAL: Mismatch");
        // Reset how many players have finished their hands.
        playersDone = 0;
        // Mark the game as started.
        gameStarted = true;
        // The house gets one card to start.
        Card[] memory cards = drawCards(1);
        Hand memory house;
        // Give the house a single card.
        house.cards[0] = cards[0];
        house.numberOfCards = 1;
        house.score = calculateScore(house);
        house.status = HandStatus.Active;
        roundToHouseHand.push(house);
        roundEnd = block.timestamp + roundLength;
        emit GameStarted(round, roundEnd);
    }

    function drawHand() external gameIsActive onlyStatus(HandStatus.Active) {
        Hand storage hand = addressToPlayer[msg.sender].roundToHand[round];
        require(hand.numberOfCards == 0, "Player already dealt");
        Card[] memory cards = drawCards(2);
        hand.cards[0] = cards[0];
        hand.cards[1] = cards[1];
        hand.numberOfCards = 2;
        hand.score = calculateScore(hand);
        emit PlayerUpdate(round, msg.sender, hand.score, hand.status);
    }

    // The player hit action. This deals another card to the player.
    function hit() external gameIsActive onlyStatus(HandStatus.Active) {
        Hand storage hand = addressToPlayer[msg.sender].roundToHand[round];
        require(hand.numberOfCards >= 2, "Player must draw");
        Card[] memory cards = drawCards(1);
        hand.cards[hand.numberOfCards] = cards[0];
        hand.numberOfCards++;
        // Recalculate the score
        hand.score = calculateScore(hand);
        if (hand.score > 21) {
            hand.status = HandStatus.Bust;
            // Mark this player as done since they went over
            // the limit.
            playersDone++;
            // If the player bust they lose their money regardless of what
            // the house ends with. The house no longer owes them their chips
            // back and does not need to hold a reserve for this player in
            // case they won.
            owedToPlayers -= hand.deposit * 2;
        }
        emit PlayerUpdate(round, msg.sender, hand.score, hand.status);
    }

    // The player stand action. The player ends their hand and waits for
    // the dealer to go.
    function stand() external gameIsActive onlyStatus(HandStatus.Active) {
        Hand storage hand = addressToPlayer[msg.sender].roundToHand[round];
        require(hand.numberOfCards >= 2, "Player must draw");
        hand.status = HandStatus.Stand;
        // Mark this hand as done so we know how many players
        // we stil have left.
        playersDone++;
        // Add this player to the total of deposits for players who got this score.
        roundToScoreToDeposit[round][hand.score] += hand.deposit;
        emit PlayerUpdate(round, msg.sender, hand.score, hand.status);
    }

    // End the round by having the dealer go until they are above or equal to 17. Calculate the
    // dealers final score and calculate winners and lossers.
    function endRound() external onlyOwner gameIsActive {
        // Require that no players are still active.
        require(
            addressesInRound[round].length == playersDone ||
                block.timestamp >= roundEnd,
            "Players not done"
        );
        // Get a ton of cards and then "draw" until we hit 17 or above.
        Hand storage house = roundToHouseHand[round];
        uint8 maxCardsForHouse = MAX_CARDS_PER_HAND - house.numberOfCards;
        Card[] memory cards = drawCards(maxCardsForHouse);
        uint256 houseIter = 0;
        while (house.score < 17) {
            house.cards[house.numberOfCards] = cards[houseIter];
            house.numberOfCards++;
            house.score = calculateScore(house);
            houseIter++;
        }

        // Update the status of the house.
        if (house.score > 21) {
            house.status = HandStatus.Bust;
        } else {
            house.status = HandStatus.Stand;
        }

        // Iterate over the possible scores a user could have ended the round with.
        // And update how much the house now owes players based on the results of
        // this round. If the house was a bust everyone who did not previously bust
        // wins, so we don't need to update anything. The amount owed to players who
        // bust is dealt with at the time they bust.
        if (house.status != HandStatus.Bust) {
            for (uint256 score = 2; score <= 21; score++) {
                if (roundToScoreToDeposit[round][score] == 0) {
                    continue;
                } else if (house.score > score) {
                    // Players who scored less than the house lose their chips and the house
                    // no longer potentially owed them so that can be freed up as well.
                    owedToPlayers -= roundToScoreToDeposit[round][score] * 2;
                } else if (house.score == score) {
                    // If the player tied the house they get their chips back.
                    owedToPlayers -= roundToScoreToDeposit[round][score];
                }
            }
        }

        round++;
        gameStarted = false;
        emit GameEnded(round - 1);
    }

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Fund functions.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------

    // Add funds to the house.
    function houseDeposit() external payable onlyOwner returns (uint256) {
        return address(this).balance;
    }

    // The owner can pull funds from the house. Only allow the house to withdraw funds that
    // are certainly not owed to players.
    function houseWithdraw(uint256 amount) external onlyOwner {
        // Make sure the house isn't withdrawing money they potentially owe to users.
        uint256 maxWithdrawAmount = maxHouseWithdraw();
        require(amount <= maxWithdrawAmount, "Insufficient funds");
        payable(owner()).transfer(amount);
    }

    function playerWithdrawForRound(uint256 round_) external returns (uint256) {
        Player storage player = addressToPlayer[msg.sender];
        if (player.roundsWithdrawn[round_]) {
            return 0;
        } else {
            uint256 owed = owedForRound(round_);
            player.roundsWithdrawn[round_] = true;
            if (owed > 0) {
                owedToPlayers -= owed;
                payable(msg.sender).transfer(owed);
            }
            return owed;
        }
    }

    function owedForRound(uint256 round_) public view returns (uint256) {
        // If the player has already withdrawn for this round they aren't owed anything.
        if (addressToPlayer[msg.sender].roundsWithdrawn[round_]) {
            return 0;
        }
        Hand memory playerHand = addressToPlayer[msg.sender].roundToHand[
            round_
        ];
        require(round_ < roundToHouseHand.length, "Out of bounds");
        Hand memory houseHand = roundToHouseHand[round_];
        uint256 owed;
        if (
            playerHand.status != HandStatus.Stand ||
            houseHand.status == HandStatus.Active
        ) {
            // If they player bust they lost. If the player is still active that
            // means they didn't complete their turn in the allowed time, meaning
            // they lost. If the house is still active this round hasn't ended yet.
            owed = 0;
        } else if (
            houseHand.status == HandStatus.Bust ||
            (playerHand.score > houseHand.score)
        ) {
            owed = playerHand.deposit * 2;
        } else if (playerHand.score == houseHand.score) {
            owed = playerHand.deposit;
        }
        return owed;
    }

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Owner game alteration functions.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------

    function setMinBid(uint256 minBid_) external onlyOwner {
        minBid = minBid_;
    }

    function setMaxBid(uint256 maxBid_) external onlyOwner {
        maxBid = maxBid_;
    }

    function setRoundLength(uint256 seconds_) external onlyOwner {
        roundLength = seconds_;
    }

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Getters.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------

    function maxHouseWithdraw() public view returns (uint256) {
        return address(this).balance - owedToPlayers;
    }

    function getPlayerHandForAddress(address playerAddress)
        external
        view
        returns (
            uint8,
            HandStatus,
            uint256,
            uint256
        )
    {
        return (
            addressToPlayer[playerAddress].roundToHand[round].score,
            addressToPlayer[playerAddress].roundToHand[round].status,
            addressToPlayer[playerAddress].roundToHand[round].deposit,
            addressToPlayer[playerAddress].roundToHand[round].numberOfCards
        );
    }

    function getHouseForRound(uint256 round_)
        public
        view
        returns (
            uint256,
            uint256,
            HandStatus
        )
    {
        return (
            roundToHouseHand[round_].score,
            roundToHouseHand[round_].numberOfCards,
            roundToHouseHand[round_].status
        );
    }

    function getCard(
        address playerAddress,
        uint256 round_,
        uint256 cardIdx
    ) external view returns (Card) {
        require(
            cardIdx <
                addressToPlayer[playerAddress]
                    .roundToHand[round_]
                    .numberOfCards,
            "Out of bounds"
        );
        return
            addressToPlayer[playerAddress].roundToHand[round_].cards[cardIdx];
    }

    function getHouseCard(uint256 round_, uint256 cardIdx)
        external
        view
        returns (Card)
    {
        require(
            cardIdx < roundToHouseHand[round_].numberOfCards,
            "Out of bounds"
        );
        return roundToHouseHand[round_].cards[cardIdx];
    }

    function numberOfAddressesInRound(uint256 round_)
        external
        view
        returns (uint256)
    {
        return addressesInRound[round_].length;
    }

    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------
    // Internal game play functions.
    // ------------------------------------------------------------------------
    // ------------------------------------------------------------------------

    function drawCards(uint8 numCards)
        internal
        view
        virtual
        returns (Card[] memory)
    {
        // This is not the best way to create a random card draw. This is just a quick implementation of
        // a card draw that made it easy to get started with Solidity.
        // The logic is take a random number and mod 13 it to get a card (0 to 12). Then divide that
        // random number by 10 and repeat. If the random number is 0, meaning we've depleted it,
        // get another random number and keep going.
        require(numCards <= 75, "Max 75 cards");
        uint256 startRandNum = generateRandomNumber(uint256(numCards));
        uint256 randNum = startRandNum;
        // Can we define the amount of space needed for a memory array before hand?
        Card[] memory cards = new Card[](numCards);
        for (uint256 i = 0; i < numCards; i++) {
            Card card = Card(randNum % (uint8(Card.Ace) + 1));
            cards[i] = card;
            // After getting a card remove the last digit so on the next iteration we get a different card.
            randNum /= 10;
            if (randNum == 0) {
                // Use the full random number received to shuffle the next deck.
                startRandNum = generateRandomNumber(startRandNum);
                randNum = startRandNum;
            }
        }
        return cards;
    }

    function generateRandomNumber(uint256 number)
        internal
        view
        returns (uint256)
    {
        /* solhint-disable not-rely-on-time, not-rely-on-block-hash */
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        blockhash(block.number),
                        roundToHouseHand[round].cards,
                        owedToPlayers,
                        addressesInRound[round],
                        number
                    )
                )
            );
        /* solhint-enable not-rely-on-time, not-rely-on-block-hash  */
    }

    function calculateScore(Hand memory hand) internal pure returns (uint8) {
        // Sum up all of the cards to the highest possible score given the cards.
        uint256 aces = 0;
        uint8 score = 0;
        for (uint256 i = 0; i < hand.numberOfCards; i++) {
            Card card = hand.cards[i];
            score += cardValue(card);
            if (card == Card.Ace) {
                aces++;
            }
        }

        // If we have aces and are over 21 we should switch an ace from an 11 to
        // a 1 by subtracting 10 from the score. As soon as we are under 21 we
        // should stop so that our score is maximized.
        while (aces != 0 && score > 21) {
            // Drop 10 off the score to switch an ace back to a 1 from an 11.
            score -= 10;
            aces -= 1;
        }
        return score;
    }

    function cardValue(Card card) internal pure returns (uint8) {
        if (card == Card.Ace) {
            // For aces increase the score by the max value (11) and then
            // if we go over revert back to 1s as needed.
            return 11;
        } else if (card >= Card.Ten) {
            return 10;
        } else {
            return uint8(card) + 2;
        }
    }
}