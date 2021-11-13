//SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol"; //interface to prevent overflow - common is zeplin

contract FundMe{
    using SafeMathChainlink for uint256;
    //uses imported contract for the specified variable type
    
    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;
    address public owner;
    
    constructor() public{
        owner = msg.sender;
    }
    
    //payable keyword allows function to pay for things (use currency)
    function fund() public payable {
        uint256 minimumUSD = 50 * 10 ** 18;
        require(getConversionRate(msg.value)>=minimumUSD, "You need to spend more ETH");
        
        //msg.sender and msg.value are keywords in every contract call
        //msg.sender is the address of the sender and msg.value is the amount sent
        addressToAmountFunded[msg.sender] += msg.value;
        
       funders.push(msg.sender);
        
    }
    
    function getVersion() public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e); //address comes from https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd scroll down to contract
        return priceFeed.version();
    }
    
    //find ETH -> USD conversion rate
    function getPrice() public view returns (uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        (uint80 roundID, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
        return uint256(answer);
    }
    
    function getConversionRate(uint256 ethAmount) public view returns (uint256){
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUSD = (ethPrice * ethAmount) / 100000000000;
        return ethAmountInUSD;
    }
    
    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
    
    function withdraw() payable onlyOwner public {
        msg.sender.transfer(address(this).balance);
        for (uint256 funderIndex = 0; funderIndex<funders.length; funderIndex++){
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
    }
    
}