// contracts/ExmplCrowdsale.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.5.5;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.4.0/contracts/crowdsale/Crowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.4.0/contracts/crowdsale/distribution/PostDeliveryCrowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.4.0/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.4.0/contracts/crowdsale/validation/TimedCrowdsale.sol";


/**
 * @title ExmplCrowdsale
 * @dev Formed and tested crowdsale.
 */
contract ExmplCrowdsale is Crowdsale, CappedCrowdsale, TimedCrowdsale, PostDeliveryCrowdsale {
    constructor (
        uint256 rate,
        address payable wallet,
        IERC20 token,
        uint256 cap,             // total cap, in wei
        uint256 openingTime,     // opening time in unix epoch seconds
        uint256 closingTime      // closing time in unix epoch seconds
    )
        public
        PostDeliveryCrowdsale()
        Crowdsale(rate, wallet, token)
        CappedCrowdsale(cap)
        TimedCrowdsale(openingTime, closingTime)
    {
    }
}