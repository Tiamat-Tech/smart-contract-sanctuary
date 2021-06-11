// SPDX-License-Identifier: ING B.V.
pragma solidity ^0.8.0;

import "./RestrictedToken.sol";

contract IEUR is RestrictedToken {
    string NAME = "IEuro";
    string SYMBOL = "IEUR";
    uint256 INITIAL_SUPPLY = 1000000;
    address[] INITIAL_ALLOWED_ADDRESSES;

    constructor()
        RestrictedToken(NAME, SYMBOL, INITIAL_SUPPLY, INITIAL_ALLOWED_ADDRESSES)
    {}
}