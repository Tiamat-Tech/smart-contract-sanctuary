//contracts/TTT_token.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/crowdsale/Crowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/crowdsale/validation/WhitelistCrowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/crowdsale/validation/TimedCrowdsale.sol";

contract ICO_TTT is TimedCrowdsale, WhitelistCrowdsale {
    
    //Sum of 3 periods = 47 days
    uint256 constant ICO_length = 47 days;
   
    constructor(
        address payable wallet,
        IERC20 token
        )   Crowdsale(1, wallet, token) TimedCrowdsale(block.timestamp, block.timestamp + ICO_length) WhitelistCrowdsale() public {
    }
    
    function rate() public view returns (uint256) {
       uint256 timePassed = block.timestamp - openingTime();
       uint256 period_1 = openingTime() + 3 days;
       // 1 month = 30 days
       uint256 period_2 = period_1 + 30 days;
       uint256 period_3 = period_2 + 2 weeks;
       
       if (timePassed < period_1){
         return 42;
       }
       if (timePassed < period_2){
         return 21;
       }
       if (timePassed < period_3){
         return 8;
       }
       return super.rate();
    }
    
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(rate());
    }
}