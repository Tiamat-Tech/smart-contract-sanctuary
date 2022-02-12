pragma solidity 0.8.3;

// SPDX-License-Identifier: MIT



import "./GamesCore.sol";

contract CoinFlip is GamesCore {
    using SafeERC20 for IERC20;

    constructor(address _croupier, address _token) {
        croupier = _croupier;
        token = IERC20(_token);
        profitTaker = msg.sender;

        edge = 5;
        minBet = 0.1 ether;
        maxBet = 10 ether;
    }

    /**
        * @notice Add new game
        * @param _seed: Uniqual value for each game
    */
    function play(uint256 _choice, uint256 _betAmount, bytes32 _seed) public payable betInRange(_betAmount) uniqueSeed(_seed) {
        require(_choice == 0 || _choice == 1, 'CoinFlip: Choice should be 0 or 1');
        require(_betAmount != 0, 'CoinFlip: Bet amount couldnt be 0');

        uint256 possiblePrize = _betAmount * (200 - edge) / 100;
        bool useToken = msg.value == 0;

        _assertContractHasEnoughFunds(possiblePrize, useToken);
        _receiveBet(_betAmount, useToken);

        Game storage game = games[_seed];

        totalGamesCount++;

        game.id = totalGamesCount;
        game.player = msg.sender;
        game.bet = _betAmount;
        game.state = GameState.PENDING;
        game.choice = _choice;
        game.useToken = useToken;

        houseProfitEther += int256(game.bet);
        listGames.push(_seed);

        emit GameCreated(
            game.player,
            game.bet,
            game.choice,
            _seed,
            true,
            useToken
        );
    }

    /**
        * @notice Confirm the game, with seed
        * @param _seed: Uniqual value for each game
    */
    function confirm(
        bytes32 _seed,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public override onlyCroupier {
        Game storage game = games[_seed];

        require(game.state == GameState.PENDING, 'CoinFlip: Game already played');

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _seed));

        require(ecrecover(prefixedHash, _v, _r, _s) == croupier, 'CoinFlip: Invalid signature');

        game.result = uint256(_s) % 2;

        if (game.choice == game.result) {
            game.prize = game.bet * (200 - edge) / 100;
            game.state = GameState.WON;

            _payoutWinnings(game.player, game.prize, game.useToken);

            houseProfitEther -= int256(game.prize);
        } else {
            game.prize = 0;
            game.state = GameState.LOST;
        }

        emit GamePlayed(
            game.player,
            game.id,
            (200 - edge),
            game.bet,
            game.prize,
            game.choice,
            game.result,
            _seed,
            true,
            game.useToken,
            game.state
        );
    }
}