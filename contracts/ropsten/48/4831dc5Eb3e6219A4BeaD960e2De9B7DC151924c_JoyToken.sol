// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./bases/BaseERC20Token.sol";

contract JoyToken is BaseERC20Token {
    constructor()
        BaseERC20Token("Joy Token", "$JOY", 18, 500_000e18)
    {
    }
}