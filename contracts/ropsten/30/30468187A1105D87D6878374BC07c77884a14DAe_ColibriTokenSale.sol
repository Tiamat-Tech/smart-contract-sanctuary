// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./helpers/PostDeliveryCrowdsale.sol";

contract ColibriTokenSale is PostDeliveryCrowdsale {
    using SafeMath for uint256;
    uint256 private _rate;

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
    {
        _rate = rate;
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount)
        internal
        view
        override
        returns (uint256)
    {
        return weiAmount.div(_rate);
    }
}