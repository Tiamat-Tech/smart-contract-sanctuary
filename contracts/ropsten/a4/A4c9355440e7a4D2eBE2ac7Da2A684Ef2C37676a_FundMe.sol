// SPDX-License-Identifier: MIT

pragma solidity >=0.8;

import "AggregatorV3Interface.sol";

contract FundMe {
    mapping(address => uint256) public addressToAmountFunded;

    address[] public funders;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    address netTest = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;

    function fund() public payable {
        //$50
        uint256 minimumUSD = 50 * 10 * 18;

        //1gwei < $50
        require(
            getConversionRate(msg.value) >= minimumUSD,
            "You need to spend more ETH!"
        );

        addressToAmountFunded[msg.sender] += msg.value;
        // what the ETH -> USD conversion rate
        // data.chain.link
        funders.push(msg.sender);
    }

    function getVersion() public view returns (uint256) {
        // addres from ricky net test
        AggregatorV3Interface priceFeed = AggregatorV3Interface(netTest);
        return priceFeed.version();
    }

    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(netTest);
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        // (
        //     uint80 roundId,
        //     int256 answer,
        //     uint256 startedAt,
        //     uint256 updatedAt,
        //     uint80 answeredInRound
        // ) = priceFeed.latestRoundData();

        return uint256(answer * 10000000000);
    }

    function getConversionRate(uint256 ethAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        return ethAmountInUsd;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function withdraw() public payable onlyOwner {
        // only want the contract admin/owner
        payable(msg.sender).transfer(address(this).balance);
        // msg.sender.transfer(address(this).balance);

        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }

        funders = new address[](0);
    }
}