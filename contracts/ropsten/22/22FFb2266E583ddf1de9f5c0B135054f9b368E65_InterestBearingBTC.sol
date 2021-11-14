// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract InterestBearingBTC is ERC20, ERC20Permit {
    constructor()
        ERC20("Interest-Bearing BTC", "ibBTC")
        ERC20Permit("Interest-Bearing BTC")
    {
        _mint(msg.sender, 100000000 * 10**decimals());
    }
}