pragma solidity ^0.8.0;

/*

$$$$$$$\  $$$$$$$$\  $$$$$$\  $$$$$$$$\  $$$$$$\   $$$$$$\  
$$  __$$\ $$  _____|$$  __$$\ $$  _____|$$  __$$\ $$  __$$\ 
$$ |  $$ |$$ |      $$ /  \__|$$ |      $$ /  \__|$$ /  \__|
$$$$$$$  |$$$$$\    $$ |      $$$$$\    \$$$$$$\  \$$$$$$\  
$$  __$$< $$  __|   $$ |      $$  __|    \____$$\  \____$$\ 
$$ |  $$ |$$ |      $$ |  $$\ $$ |      $$\   $$ |$$\   $$ |
$$ |  $$ |$$$$$$$$\ \$$$$$$  |$$$$$$$$\ \$$$$$$  |\$$$$$$  |
\__|  \__|\________| \______/ \________| \______/  \______/ 
                                                                                                                   
*/

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hardhat/console.sol';

contract RockPaperScissors is Ownable {
    enum Phase {
        Pause,
        Commit,
        Reveal
    }
    enum Choice {
        Rock,
        Paper,
        Scissors
    }
    enum GameStatus {
        Undecided,
        Finalized
    }

    struct Game {
        uint32 id;
        GameStatus status;
        uint32 winnerId;
        Player player1;
        Player player2;
    }

    struct Player {
        uint32 nftId;
        bytes32 commitment;
        Choice[] choices;
    }

    // This stores gameplay. By the end of the tournament this will have 8190 games stored in it.
    // There are 8192 tokens which in a single elim tournament means 8191 games, but the final is not R/P/S so only 8190
    // the gameID can be computed from the bracket and the two nft IDS playing against one another determistically and at runtime
    // The formula is
    // (8192 - 2 ^ (12 - round)) + nftID / 2 ^ (round + 1)
    mapping(uint256 => Game) public games;

    IERC721Enumerable nftContract;
    IERC20 oracleToken;
    address oracleAccount;

    uint8 public currentRound;
    Phase public currentPhase;

    // Returns 1 if choice1 beats choice 2, 2 if choice 2 beats 1, 0 if a tie, -1 if both lose (both undefined). This is constant- array constants not yet implemented
    uint8[3][3] private RPS_CALCULATION = [[0, 2, 1], [1, 0, 2], [2, 1, 0]];

    uint8 private constant NUM_CHOICES = 3;

    constructor(
        IERC721Enumerable _nftContract,
        IERC20 _oracleToken,
        address _oracleAccount
    ) {
        nftContract = _nftContract;
        oracleToken = _oracleToken;
        oracleAccount = _oracleAccount;
    }

    // Tie resolution idea?
    function wipeGame(uint32 gameId) external onlyOwner {
        games[gameId].player1.commitment = 0;
        games[gameId].player2.commitment = 0;
    }

    function advanceRound(uint8 newRound, Phase phase) external onlyOwner {
        currentRound = newRound;
        currentPhase = phase;
    }

    function commit(
        uint32 nftId,
        uint32 gameId,
        bytes32 commitment
    ) public {
        require(currentPhase == Phase.Commit, 'Not commit phase');
        require(_validateOwner(nftId), 'Unauthorized');
        require(_validateCorrectGame(gameId, nftId), 'Inactive Game');
        require(_validateWinnerOfPreviousRound(nftId), 'Disqualified');
        bool isPlayer1 = _isPlayer1(nftId, currentRound);
        Game storage game = games[gameId];
        // first person to commit to this game, need to initialize game
        if (game.id == 0) {
            game.id = gameId;
        }
        Player storage player = (isPlayer1) ? game.player1 : game.player2;
        require(player.commitment == 0, 'Commitment already made');
        player.nftId = nftId;
        player.commitment = commitment;
    }

    function reveal(
        uint32 nftId,
        uint32 gameId,
        Choice[] memory choices,
        bytes32 blindingFactor
    ) public {
        require(currentPhase == Phase.Reveal, 'Not reveal phase');
        require(choices.length == NUM_CHOICES, 'Incorrect Number Of Choices');
        for (uint256 i; i < choices.length; i++) {
            require(_validateChoice(choices[i]), 'Invalid Choice');
        }
        // We can save some gas and skip validating ownership of nft. We rely on ownership validated during commit phase and trust that the person with the blinding factor is the same person

        Game storage game = games[gameId];
        Player storage player = _isPlayer1(nftId, currentRound) ? game.player1 : game.player2;
        require(player.commitment != 0, 'Commitment not made');
        require(
            keccak256(
                abi.encodePacked(nftId, gameId, choices[0], choices[1], choices[2], blindingFactor)
            ) == player.commitment,
            'Hash not equal to commitment'
        );
        player.choices = choices;
        if (game.player1.choices.length > 0 && game.player2.choices.length > 0) {
            _updateGameStatus(game);
        }
    }

    function _validateChoice(Choice choice) private pure returns (bool) {
        return choice == Choice.Rock || choice == Choice.Paper || choice == Choice.Scissors;
    }

    function _validateOwner(uint256 nftId) internal view returns (bool) {
        return nftContract.ownerOf(nftId) == msg.sender;
    }

    function _validateCorrectGame(uint256 gameId, uint256 nftId) internal view returns (bool) {
        return _findGameId(nftId, currentRound) == gameId;
    }

    function _validateWinnerOfPreviousRound(uint256 nftId) private returns (bool) {
        if (currentRound == 0) {
            return true;
        }
        uint256 previousGameId = _findGameId(nftId, currentRound - 1);
        Game storage previousGame = games[previousGameId];
        if (previousGame.status == GameStatus.Undecided) {
            _updateGameStatus(previousGame);
        }

        return nftId == previousGame.winnerId;
    }

    function _updateGameStatus(Game storage game) private {
        uint32 winner = _computeWinner(game);
        game.status = GameStatus.Finalized;
        game.winnerId = winner;
    }

    // this should be called when the round is over, or when both players have revealed.
    function _computeWinner(Game storage game) private view returns (uint32) {
        // Neither player revealed
        if (game.player1.choices.length == 0 && game.player2.choices.length == 0) {
            return 0;
            // Player 2 did not reveal
        } else if (game.player1.choices.length > 0 && game.player2.choices.length == 0) {
            return game.player1.nftId;
            // Player 1 did not reveal
        } else if (game.player1.choices.length == 0 && game.player2.choices.length > 0) {
            return game.player2.nftId;
        }

        for (uint8 i = 0; i < NUM_CHOICES; i++) {
            uint8 result = RPS_CALCULATION[uint256(game.player1.choices[i])][
                uint256(game.player2.choices[i])
            ];
            if (result > 0) {
                return (result == 1) ? game.player1.nftId : game.player2.nftId;
            }
        }
        return
            _coinflip(game.player1.nftId, game.player2.nftId)
                ? game.player1.nftId
                : game.player2.nftId;
    }

    // returns 0 for player 1 victory, 1 for player 2 victory
    function _coinflip(uint256 player1, uint256 player2) private view returns (bool) {
        return uint256(_pseudoRandomHash(player1, player2)) % 2 == 0;
    }

    function _pseudoRandomHash(uint256 player1, uint256 player2) private view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    player1,
                    player2,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    blockhash(block.number - 1),
                    IERC20(oracleToken).balanceOf(oracleAccount)
                )
            );
    }

    // compute gameID form _nftID and round #
    // The formula is
    // (8192 - 2 ** (13 - round)) + nftID / 2 ** (round + 1)
    function _findGameId(uint256 nftId, uint256 round) internal pure returns (uint256) {
        // Using bitwise ops instead of exponentiation to save gas
        return (8192 - (2 << (12 - round))) + nftId / (2 << (round));
    }

    // Determiens whether this nft is player 1 or 2 in the given round. Returns true for player1, false for player2
    // This formula is
    // (nftId / 2 ** round) % 2
    function _isPlayer1(uint256 nftId, uint256 round) internal pure returns (bool) {
        // Using bitwise ops instead of exponentiation to save gas
        // Necessary to prevent underflow
        if (round == 0) {
            return nftId % 2 == 0;
        }
        return (nftId / (2 << (round - 1))) % 2 == 0;
    }
}