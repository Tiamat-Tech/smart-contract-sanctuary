//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
struct OracleData {
    int256[] values;
}
struct RoundData {
    bool completed;
    mapping(address => OracleData) data;
    int256[] values;
    uint80 count;
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

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
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract FeedStorage is Initializable, Ownable {
    string private _description;
    uint8 private _decimals;
    uint256 private _version;
    uint256 private blocks_frame;

    address[] private authorized_oracles;
    uint80 last_round;
    mapping(uint80 => RoundData) FeedData;

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function description() public view returns (string memory) {
        return _description;
    }

    function version() public view returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 _roundId)
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        uint256 started = 0;

        if (_roundId >= 1) {
            started = (_roundId - 1) * blocks_frame;
        }

        return (
            roundId,
            FeedData[_roundId].values[0],
            started,
            started + blocks_frame,
            FeedData[_roundId].count
        );
    }

    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return getRoundData(last_round);
    }

    function checkOracle() private {
        uint256 i = 0;
        while (authorized_oracles[i] == msg.sender) {
            return;
        }
        revert("unauthorized sender");
    }

    function findValue(address value) private returns (uint256) {
        uint256 i = 0;
        while (authorized_oracles[i] != value) {
            i++;
        }
        return i;
    }

    function removeByValue(address value) private {
        uint256 i = findValue(value);
        removeByIndex(i);
    }

    function removeByIndex(uint256 i) private {
        while (i < authorized_oracles.length - 1) {
            authorized_oracles[i] = authorized_oracles[i + 1];
            i++;
        }
        delete authorized_oracles[authorized_oracles.length - 1];
        //authorized_oracles.length--;
    }

    function removeOracles(address[] memory candidates) public onlyOwner {
        for (uint256 i = 0; i < candidates.length; i += 1) {
            //for loop example
            removeByValue(candidates[i]);
        }
        authorized_oracles.pop();
    }

    function addOracles(address[] memory candidates) public onlyOwner {
        for (uint256 i = 0; i < candidates.length; i += 1) {
            //for loop example
            authorized_oracles.push(candidates[i]);
        }
    }

    function initialize(
        string memory _desc,
        uint8 _dec,
        uint256 _ver,
        uint256 _blocks_frame
    ) public payable initializer {
        console.log("Deploying a FeedStorage with name:", _desc);
        _description = _desc;
        _version = _ver;
        _decimals = _dec;
    }

    constructor(
        string memory _desc,
        uint8 _dec,
        uint256 _ver,
        uint256 _blocks_frame
    ) {
        initialize(_desc, _dec, _ver, _blocks_frame);
    }

    function feed_name() public view returns (string memory) {
        return _description;
    }

    function oracles() public view returns (address[] memory) {
        return authorized_oracles;
    }

    function pushRoundData(uint32 round, int256 value) public {
        checkOracle();
        if (round <= last_round) {
            revert("invalid round");
        }
        FeedData[round].data[msg.sender].values.push(value);
        FeedData[round].count++;

        // //int256[] storage vals;
        if (FeedData[round].count >= (authorized_oracles.length * 2) / 3) {
            console.log("Agregate:", "a");
            int256 min_len = 0;
            int256[] memory vals = new int256[](FeedData[round].count);
            uint256 j = 0;
            console.log("Agregate:", "a");
            for (
                uint256 index = 0;
                index < authorized_oracles.length;
                index++
            ) {
                console.log("Agregate:", index, round);
                if (
                    FeedData[round]
                        .data[authorized_oracles[index]]
                        .values
                        .length == 0
                ) {
                    continue;
                }
                console.log("Agregate 3 j=%d index=%d", j, index);
                vals[j] = FeedData[round]
                    .data[authorized_oracles[index]]
                    .values[0];
                j++;
                console.log("Agregate 3 j=%d index=%d", j, index);

                int256 avg;
                for (uint256 i = 0; i < vals.length; i++) {
                    avg += vals[i];
                }
                console.log("Agregate 4 j=%d index=%d", j);
                FeedData[round].values.push(avg / int256(vals.length));
                FeedData[round].completed = true;
                last_round = round;
            }
        }
    }
}