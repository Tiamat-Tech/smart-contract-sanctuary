// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "AggregatorV3Interface.sol";

contract FundMe {

    mapping(address => uint256) public donorsToAmount;
    address public owner;
    address[] funders;

    constructor() public {
        owner = msg.sender;
    }

    function fund() public payable {
        uint256 minUsd = 10 * 10 ** 18;
        require(getConversionRate(msg.value) >= minUsd, "You need more eth");
        donorsToAmount[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function getVersion() public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        return priceFeed.version();
    }

    function getPrice() public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        (,int256 answer,,,) = priceFeed.latestRoundData();
        return uint256(answer * 10000000000);
    }

    function getConversionRate(uint256 ethAmount) public view returns(uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 10000000000; //take the decimels off for wei
        return ethAmountInUsd;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function withdraw() payable onlyOwner public {
        msg.sender.transfer(address(this).balance);
        for(uint256 i = 0 ; i < funders.length; i++) {
            address funder = funders[i];
            donorsToAmount[funder] = 0;
        }

        funders = new address[](0);
    }
}