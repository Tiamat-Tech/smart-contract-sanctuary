// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol";

contract FundMe {
    mapping(address => uint256) public balances;
    uint256 minValue;

    constructor() public {
        minValue = 50;
    }

    function Fund() public payable {
        require(convertEthtoUSD(msg.value) >= minValue);

        balances[msg.sender] += msg.value;
    }

    function getVersion() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        );
        return priceFeed.version();
    }

    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        );
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return uint256(answer);
    }

    function convertEthtoUSD(uint256 _eth) public view returns (uint256) {
        return (getPrice() * _eth) / 100000000;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() public payable {
        address payable to = payable(msg.sender);
        to.transfer(getBalance());
    }
}