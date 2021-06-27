// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LuckyCoin is ERC20 {
    constructor() ERC20("LuckyCoin", "LUCKY") {
        _mint(msg.sender, 1000000000 * 10 ** uint256(decimals()));
    }

    function decimals() public pure override returns (uint8) {
        return 3;
    }
}