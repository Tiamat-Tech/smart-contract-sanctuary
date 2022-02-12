pragma solidity 0.8.3;

// SPDX-License-Identifier: MIT



import "./ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./GamesCore.sol";

contract WheelOfFortune is GamesCore {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Color {
        bytes1 color;
        uint8 sector;
    }

    /// Maximum possible win
    uint256 public maxPayout;

    /// Number of all sectors
    uint64 public allSectors;
    /// Number of all colors
    uint8 public allColors;

    /// Info of each color
    mapping(uint256 => Color) public colors;

    constructor(address _croupier, address _token) {
        croupier = _croupier;
        token = IERC20(_token);
        profitTaker = msg.sender;

        minBet = 0.1 ether;
        maxBet = 10 ether;
        maxPayout = 100 ether;
        edge = 1;

        addColor("p", 30);
        addColor("r", 15);
        addColor("g", 10);
        addColor("y", 5);
    }

    /**
        * @notice Find color index in 'colors' mapping
        * @param _color: Color to find
    */
    function findColor(bytes1 _color) public view returns(uint8) {
        for (uint8 index = 0; index < allColors; index++) {
            if(colors[index].color == _color) {
                return index;
            }
        }

        return 255;
    }

    /**
        * @notice Add new color to 'colors' mapping
        * @param _color: New color
        * @param _sector: Number of sectors for new color
    */
    function addColor(bytes1 _color, uint8 _sector) public onlyOwner {
        require(findColor(_color) == 255, "WheelOfFortune: Color already exist");
        require(_sector != 0, "WheelOfFortune: New sector cant be 0");

        colors[allColors].color = _color;
        colors[allColors].sector = _sector;

        allSectors += _sector;
        allColors++;
    }

    /**
        * @notice Delete color from 'colors' mapping
        * @param _index: Index of color
    */
    function deleteColor(uint8 _index) external onlyOwner {
        require(colors[_index].color != "", "WheelOfFortune: Wrong color");

        allSectors -= colors[_index].sector;
        colors[_index].color = "";
        colors[_index].sector = 0;
    }

    /**
        * @notice Calculates the coefficient for color
        * @param _choice: Index of color
    */
    function multiplier(uint256 _choice) public view returns (int128) {
        uint256 winRangeLength = colors[_choice].sector;
        uint256 rangeLength = allSectors;
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
        * @param _choice: Index of color
        * @param _bet: Bet amount
    */
    function payout(uint256 _choice, uint256 _bet) public view returns (uint256) {
        return ABDKMath64x64.mulu(multiplier(_choice), _bet);
    }

    /**
        * @notice Add new game
        * @param _choice: Index of color
        * @param _seed: Uniqual value for each game
    */
    function play(uint256 _choice, uint256 _betAmount, bytes32 _seed) external payable betInRange(_betAmount) uniqueSeed(_seed) {
        require(colors[_choice].color != "", "WheelOfFortune: Wrong color");

        uint256 possiblePrize = payout(_choice, _betAmount);
        bool useToken = msg.value == 0;

        if (possiblePrize > maxPayout) {
            possiblePrize = maxPayout;
        }

        _assertContractHasEnoughFunds(possiblePrize, useToken);
        _receiveBet(_betAmount, useToken);

        Game storage game = games[_seed];

        totalGamesCount++;

        game.id = totalGamesCount;
        game.player = msg.sender;
        game.bet = _betAmount;
        game.choice = _choice;
        game.state = GameState.PENDING;
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
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _seed));
        require(
            ecrecover(prefixedHash, _v, _r, _s) == croupier,
            "WheelOfFortune: Invalid signature"
        );

        Game storage game = games[_seed];

        require(game.id != 0, "WheelOfFortune: Game doesn't exist");
        require(
            game.state == GameState.PENDING,
            "WheelOfFortune: Game already played"
        );

        uint256 winN = (uint256(_s) % allSectors) + 1;

        uint8 index;
        for (index; index < allColors; index++) {
            if (winN < colors[index].sector) {
                break;
            }
            winN -= colors[index].sector;
        }

        if (index != game.choice) {
            game.prize = 0;
            game.state = GameState.LOST;
        } else {
            game.prize = payout(game.choice, game.bet);
            game.state = GameState.WON;

            _payoutWinnings(game.player, game.prize, game.useToken);

            houseProfitEther -= int256(game.prize);
        }
        game.result = index;

        emit GamePlayed(
            game.player,
            game.id,
            ABDKMath64x64.toUInt(multiplier(game.choice)),
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

    /**
        * @notice Update sectors number for 1 color
        * @param _index: Index of color
        * @param _newSector: Sectors number
    */
    function updateSector(
        uint8 _index,
        uint8 _newSector
    ) public onlyOwner {
        require(colors[_index].color != "", "WheelOfFortune: Wrong color");

        allSectors = allSectors + _newSector - colors[_index].sector;
        colors[_index].sector = _newSector;
    }

    /**
        * @notice Set new maxPayout
        * @param _maxPayout: New maxPayout
    */
    function setMaxPayout(uint256 _maxPayout) public onlyOwner {
        maxPayout = _maxPayout;
    }
}