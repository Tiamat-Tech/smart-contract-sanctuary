pragma solidity 0.8.3;

// SPDX-License-Identifier: MIT



import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ABDKMath64x64.sol";
import "./GamesCore.sol";

contract DiceRoll is GamesCore {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;

    /// Maximum possible win
    uint256 public maxPayout;

    /// Minimal possible choice
    uint256 public rangeMin;
    /// Maximal possible choice
    uint256 public rangeMax;
    uint256 public padding;

    constructor(address _croupier, address _token) {
        croupier = _croupier;
        token = IERC20(_token);
        profitTaker = msg.sender;

        minBet = 1 ether;
        maxBet = 5000 ether;
        maxPayout = 10000 ether;
        rangeMin = 1;
        rangeMax = 10000;
        padding = 200;
        edge = 1;

    }

    // Check that the ape rate is between min and max bet
    modifier choiceInRange(uint256 _choice) {
        require(
            _choice >= rangeMin + padding,
            "DiceRoll: Incorrect value for choice"
        );
        require(
            _choice <= rangeMax + padding,
            "DiceRoll: Incorrect value for choice"
        );
        _;
    }

    /**
        * @notice Calculates the coefficient for choice
    */
    function multiplier(bool _over, uint256 _choice)
        public
        view
        returns (int128)
    {
        uint256 winRangeLength = _over ? rangeMax - _choice + 1 : _choice;
        uint256 rangeLength = rangeMax - rangeMin + 1;
        int128 winChance = ABDKMath64x64.mul(
            ABDKMath64x64.div(
                ABDKMath64x64.fromUInt(winRangeLength),
                ABDKMath64x64.fromUInt(rangeLength)
            ),
            ABDKMath64x64.fromUInt(uint256(100))
        );

        return
            ABDKMath64x64.div(
                ABDKMath64x64.fromUInt(uint256(100).sub(edge)),
                winChance
            );
    }

    /**
        * @notice Calculates the prize when winning
        * @param _bet: Bet amount
    */
    function payout(
        bool _over,
        uint256 _choice,
        uint256 _bet
    ) public view returns (uint256) {
        return ABDKMath64x64.mulu(multiplier(_over, _choice), _bet);
    }

    /**
        * @notice Add new game
        * @param _choice: Choice
        * @param _over: More or less than choice
        * @param _seed: Uniqual value for each game
    */
    function play(
        uint256 _choice,
        uint256 _betAmount,
        bool _over,
        bytes32 _seed
    ) public payable betInRange(_betAmount) choiceInRange(_choice) uniqueSeed(_seed) {
        uint256 possiblePrize = payout(_over, _choice, _betAmount);
        if (possiblePrize > maxPayout) {
            possiblePrize = maxPayout;
        }

        bool useToken = msg.value == 0;

        _assertContractHasEnoughFunds(possiblePrize, useToken);
        _receiveBet(_betAmount, useToken);

        totalGamesCount++;
        Game storage game = games[_seed];

        game.id = totalGamesCount;
        game.player = msg.sender;
        game.bet = _betAmount;
        game.state = GameState.PENDING;
        game.over = _over;
        game.choice = _choice;
        game.useToken = useToken;

        houseProfitEther += int256(game.bet);
        listGames.push(_seed);

        emit GameCreated(game.player, game.bet, game.choice, _seed, game.over, game.useToken);
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

        require(game.id != 0, "DiceRoll: Game doesn't exist");
        require(
            game.state == GameState.PENDING,
            "DiceRoll: Game already played"
        );

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _seed));

        require(
            ecrecover(prefixedHash, _v, _r, _s) == croupier,
            "DiceRoll: Invalid signature"
        );

        game.result = (uint256(_s) % 10000) + 1;
        int128 _multiplier = multiplier(game.over, game.choice);

        if (
            (!game.over && (game.choice >= game.result)) ||
            (game.over && (game.choice <= game.result))
        ) {
            game.prize = payout(game.over, game.choice, game.bet);

            if (game.prize > maxPayout) {
                game.prize = maxPayout;
            }

            _payoutWinnings(game.player, game.prize, game.useToken);

            houseProfitEther -= int256(game.prize);
            game.state = GameState.WON;
        } else {
            game.prize = 0;
            game.state = GameState.LOST;
        }

        emit GamePlayed(
            game.player,
            game.id,
            ABDKMath64x64.toUInt(_multiplier),
            game.bet,
            game.prize,
            game.choice,
            game.result,
            _seed,
            game.over,
            game.useToken,
            game.state
        );
    }

    /**
        * @notice Set new range for choice
        * @param _min: New rangeMin
        * @param _max: New rangeMax
        * @param _padding: New padding
    */
    function setChoiceRange(
        uint256 _min,
        uint256 _max,
        uint256 _padding
    ) public onlyOwner {
        rangeMin = _min;
        rangeMax = _max;
        padding = _padding;
    }

    /**
        * @notice Set new maxPayout
        * @param _maxPayout: New maxPayout
    */
    function setMaxPayout(uint256 _maxPayout) public onlyOwner {
        maxPayout = _maxPayout;
    }
}