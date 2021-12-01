// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

// https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol";

contract FundMe {
    using SafeMathChainlink for uint256;

    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;
    address public owner;
    AggregatorV3Interface public priceFeed;

    constructor() public {
        //priceFeed = AggregatorV3Interface(_priceFeed);
        owner = msg.sender;
    }
}