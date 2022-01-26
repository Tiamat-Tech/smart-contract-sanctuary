// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.6;

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol";

contract FundMe {
    using SafeMathChainlink for uint256;

    address ethUsdPriceContractAddress = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;
    address public owner;

    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;

    constructor() public {
        owner = msg.sender;
    }

    function fund() public payable {

        uint256 minimumUSD = 50 * 10 ** 18;

        require(getConversionRate(msg.value) >= minimumUSD, "You need to spend more ETH");

        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function getVersion() public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceContractAddress);
        return priceFeed.version();
    }

    function getPrice() public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceContractAddress);
        (,int256 answer,,,) = priceFeed.latestRoundData();

         return uint256(answer);
    }

    function getConversionRate(uint256 ethAmount) public view returns (uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 100000000;

        return ethAmountInUsd;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only onwer can do this");
        _;
    }

    function withdraw() payable onlyOwner public {
        require(address(this).balance > 0, "You have 0 balance");
        msg.sender.transfer(address(this).balance);

        for(uint256 funderIndex=0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;

        }

        funders = new address[](0);

    }
}