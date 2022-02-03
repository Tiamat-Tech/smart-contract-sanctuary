// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";

contract Presale is Crowdsale, TimedCrowdsale {
    uint256 public _rate;
    address payable public _wallet;
    IERC20 public _token;
    uint256 public _openingTime;
    uint256 public _closingTime;
    
    constructor(uint256 rate, address payable wallet, IERC20 token, 
    uint256 openingTime, uint256 closingTime) 
    Crowdsale(rate, wallet, token)
    TimedCrowdsale(openingTime, closingTime) public {

        _rate = rate;
        _wallet = wallet;
        _token = token;
        _openingTime = openingTime;
        _closingTime = closingTime;
    } 
}