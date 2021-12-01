// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import "AggregatorV3Interface.sol";

contract FundMe {
    address public owner;
    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function fund() public payable {
        uint256 minUSD = 50 * 10**18;
        require(
            getConversionRate(msg.value) >= minUSD,
            "You need to spend more ETH"
        );
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
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
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 10000000000);
    }

    function getConversionRate(uint256 _ethAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        uint256 ethAmpuntInUsd = (ethPrice * _ethAmount) / 1000000000000000000;
        return ethAmpuntInUsd;
    }

    function withdraw() public payable onlyOwner {
        msg.sender.transfer(address(this).balance);
        for (uint256 funderIdx = 0; funderIdx < funders.length; funderIdx++) {
            addressToAmountFunded[funders[funderIdx]] = 0;
        }
        funders = new address[](0);
    }
}