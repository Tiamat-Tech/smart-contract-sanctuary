// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../libraries/BaseERC20Token.sol";

contract UsdcMock is BaseERC20Token {
    constructor()
        BaseERC20Token("USDC token", "USDC", 6, 10000_000e9)
    {
    }
}