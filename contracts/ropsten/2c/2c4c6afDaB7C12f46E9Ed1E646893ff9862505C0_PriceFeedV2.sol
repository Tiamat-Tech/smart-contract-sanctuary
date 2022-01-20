// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceFeedV2.sol";

contract PriceFeedV2 is Ownable {
    uint80 latestUpdateRoundId;
    uint80 currentRoundId;
    address public operator;

    struct RoundInfo {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(uint80 => RoundInfo) roundData;

    event UpdateRoundInfo(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    event UpdateOperator(address operatorAddr);

    constructor(address _operator) {
        operator = _operator;
        roundData[currentRoundId] = RoundInfo({
            roundId: latestUpdateRoundId,
            answer: 0,
            startedAt: block.timestamp,
            updatedAt: 0,
            answeredInRound: 0
        });
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    function description() external view returns (string memory) {
        return "Oracle for feeding ETH Price";
    }

    function version() external view returns (uint256) {
        return 3;
    }

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        require(currentRoundId != 0, "No data present");
        require(roundData[_roundId].updatedAt != 0, "Round not updated yet");
        roundId = _roundId;
        answer = roundData[_roundId].answer;
        startedAt = roundData[_roundId].startedAt;
        updatedAt = roundData[_roundId].updatedAt;
        answeredInRound = roundData[_roundId].answeredInRound;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId = roundData[latestUpdateRoundId].roundId;
        answer = roundData[latestUpdateRoundId].answer;
        startedAt = roundData[latestUpdateRoundId].startedAt;
        updatedAt = roundData[latestUpdateRoundId].updatedAt;
        answeredInRound = roundData[latestUpdateRoundId].answeredInRound;
    }

    function _setNewOperator(address _newOperator) public onlyOwner {
        operator = _newOperator;
        emit UpdateOperator(_newOperator);
    }

    function updateRoundData(int256 answer) public onlyOperator {
        require(
            roundData[latestUpdateRoundId].startedAt != block.timestamp,
            "Already update answer"
        );
        roundData[currentRoundId].answer = answer;
        roundData[currentRoundId].updatedAt = block.timestamp;
        roundData[currentRoundId].answeredInRound = 1;
        latestUpdateRoundId = currentRoundId;
        currentRoundId++;
        roundData[currentRoundId] = RoundInfo({
            roundId: latestUpdateRoundId,
            answer: 0,
            startedAt: block.timestamp,
            updatedAt: 0,
            answeredInRound: 0
        });
        emit UpdateRoundInfo(
            latestUpdateRoundId,
            answer,
            roundData[latestUpdateRoundId].startedAt,
            block.timestamp,
            1
        );
    }
}