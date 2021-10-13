// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./helpers/PostDeliveryCrowdsale.sol";

contract ColibriTokenSale is PostDeliveryCrowdsale {
    constructor(
        uint256 rate, // rate in TKNbits
        address wallet,
        IERC20 token,
        uint256 openingTime_,
        uint256 closingTime_
    )
        PostDeliveryCrowdsale(
            rate,
            payable(wallet),
            token,
            openingTime_,
            closingTime_
        )
    {}
}