// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";

contract Presale is Crowdsale, TimedCrowdsale {
    
    constructor(uint256 rate, address payable wallet, IERC20 token, 
    uint256 openingTime, uint256 closingTime) 
    Crowdsale(rate, wallet, token)
    TimedCrowdsale(openingTime, closingTime) public {} 
}