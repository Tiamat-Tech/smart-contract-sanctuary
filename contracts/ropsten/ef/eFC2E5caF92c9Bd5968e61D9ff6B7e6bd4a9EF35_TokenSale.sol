// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./helpers/PostDeliveryCrowdsale.sol";

contract TokenSale is PostDeliveryCrowdsale {
    constructor(
        uint8 decimals_,
        uint256[3][] memory rates_, // rate in TKNbits
        address wallet_,
        IERC20 token_
    ) PostDeliveryCrowdsale(decimals_, rates_, payable(wallet_), token_) {}
}