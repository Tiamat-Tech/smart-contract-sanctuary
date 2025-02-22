// SPDX-License-Identifier: MIT
pragma solidity ^0.5.5;

import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";

contract RunsCoinCrowdsale is Crowdsale {
    constructor(
        uint256 rate,
        address payable wallet,
        IERC20 token
    ) public Crowdsale(rate, wallet, token) {}
}