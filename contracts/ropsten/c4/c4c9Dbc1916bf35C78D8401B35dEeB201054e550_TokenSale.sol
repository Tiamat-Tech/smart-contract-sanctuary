// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./helpers/PostDeliveryCrowdsale.sol";

contract TokenSale is PostDeliveryCrowdsale {
    constructor(
        uint8 decimals,
        uint256[3][] memory rates, // rate in TKNbits
        address wallet,
        IERC20 token
    ) PostDeliveryCrowdsale(decimals, rates, payable(wallet), token) {}
}