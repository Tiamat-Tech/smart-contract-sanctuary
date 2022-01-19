// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol";

contract FundMe {
    
    using SafeMathChainlink for uint256;
    address[]  public funders;
    address public owner;

    constructor() public{
        owner = msg.sender;
    } 

    mapping(address => uint256 ) public addressToAmountFunded;

    function fund() public payable {
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);

        // what is the eth -> usd conversion rate
    }

    function getVersion() public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        return priceFeed.version();
    }
    
    function getPrice() public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        (,int256 answer,,,) = priceFeed.latestRoundData();
         // ETH/USD rate in 18 digit 
         return uint256(answer * 10000000000);
    }
    
    // 1000000000
    function getConversionRate(uint256 ethAmount) public view returns (uint256){
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1000000000000000000;
        // the actual ETH/USD conversation rate, after adjusting the extra 0s.
        return ethAmountInUsd;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function withdraw() payable onlyOwner public{
        msg.sender.transfer(address(this).balance);
        for(uint256 funderIndex=0; funderIndex<funders.length; funderIndex++){
            address funder = funders[ funderIndex ];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
    }
}