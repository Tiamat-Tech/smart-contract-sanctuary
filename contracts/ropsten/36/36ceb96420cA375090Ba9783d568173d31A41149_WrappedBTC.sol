// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract WrappedBTC is ERC20, ERC20Permit {
    constructor() ERC20("Wrapped BTC", "WBTC") ERC20Permit("Wrapped BTC") {
        _mint(msg.sender, 100000000 * 10**decimals());
    }

    function decimals() public view override returns (uint8) {
        return 8;
    }
}