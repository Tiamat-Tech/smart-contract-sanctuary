//SPDX-License-Identifier: Unlicense
pragma solidity =0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Chess {
    using Counters for Counters.Counter;

    event NewGame(uint256 id, address from);
    event Move(uint256 id, address from, string color, string move);

    mapping(uint256 => string[]) public whiteMovesMapping;
    mapping(uint256 => string[]) public blackMovesMapping;
    Counters.Counter private count;

    function getCount() external view returns (uint256) {
        return Counters.current(count);
    }

    function getPGN(uint256 _gameId) external view returns (string memory) {
        string[] memory whiteMoves = whiteMovesMapping[_gameId];
        string[] memory blackMoves = blackMovesMapping[_gameId];
        string memory ret = "";
        for (uint256 i = 0; i < whiteMoves.length; i++) {
            string memory wholePart = generateMovePGN(i, whiteMoves, "white");
            ret = string(abi.encodePacked(ret, wholePart));
            // check to ensure black made a move this turn
            if (blackMoves.length == whiteMoves.length) {
                wholePart = generateMovePGN(i, blackMoves, "black");
                ret = string(abi.encodePacked(ret, wholePart));
            }
        }
        return ret;
    }

    function generateMovePGN(
        uint256 _i,
        string[] memory _moveArray,
        string memory _color
    ) internal pure returns (string memory) {
        string memory numberPart = "";
        if (
            keccak256(abi.encodePacked(_color)) ==
            keccak256(abi.encodePacked("white"))
        ) {
            // PGN notation is 1-indexed
            uint256 moveNum = _i + 1;
            numberPart = string(
                abi.encodePacked(Strings.toString(moveNum), ". ")
            );
        }

        string memory wholePart = string(
            abi.encodePacked(numberPart, _moveArray[_i])
        );
        return string(abi.encodePacked(wholePart, " "));
    }

    function createGame() external {
        uint256 gameId = Counters.current(count);
        whiteMovesMapping[gameId] = new string[](gameId);
        blackMovesMapping[gameId] = new string[](gameId);
        Counters.increment(count);
        emit NewGame(gameId, msg.sender);
    }

    function move(
        uint256 _gameId,
        string memory _color,
        string memory _move
    ) external {
        string[] storage whiteMoves = whiteMovesMapping[_gameId];
        string[] storage blackMoves = blackMovesMapping[_gameId];
        require(isValidMove(whiteMoves, blackMoves, _color));
        if (
            keccak256(abi.encodePacked(_color)) ==
            keccak256(abi.encodePacked("white"))
        ) {
            whiteMoves.push(_move);
        } else {
            blackMoves.push(_move);
        }
        emit Move(_gameId, msg.sender, _color, _move);
    }

    function isValidMove(
        string[] memory _whiteMoves,
        string[] memory _blackMoves,
        string memory _color
    ) internal pure returns (bool) {
        return isValidColor(_whiteMoves, _blackMoves, _color);
        // do smarter things based on string value entered
    }

    function isValidColor(
        string[] memory _whiteMoves,
        string[] memory _blackMoves,
        string memory _color
    ) internal pure returns (bool) {
        if (
            _whiteMoves.length == _blackMoves.length &&
            keccak256(abi.encodePacked(_color)) ==
            keccak256(abi.encodePacked("white"))
        ) {
            return true;
        }
        if (
            _whiteMoves.length > _blackMoves.length &&
            keccak256(abi.encodePacked(_color)) ==
            keccak256(abi.encodePacked("black"))
        ) {
            return true;
        }
        return false;
    }
}