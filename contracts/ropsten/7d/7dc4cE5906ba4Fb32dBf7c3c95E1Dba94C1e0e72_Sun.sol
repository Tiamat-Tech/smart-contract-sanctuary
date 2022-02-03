// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/IndividuallyCappedCrowdsale.sol";

contract Sun is ERC20, ERC20Detailed {

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    )   public 
    ERC20Detailed(name, symbol, decimals) {
        _mint(msg.sender, 1000000000000000000000000000);
    }
}

contract MyCrowdsale is Crowdsale, TimedCrowdsale,
IndividuallyCappedCrowdsale {

    constructor(
        uint256 openingTime,
        uint256 closingTime,
        uint256 rate,
        address payable wallet,
        IERC20 token
    )   public
    Crowdsale(rate, wallet, token)
    TimedCrowdsale(openingTime, closingTime) {}
}