// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CarbonCredit is ERC20 {
    constructor() ERC20("Carbon Credit Investment6 (CCI)", "CCI6") {
        _mint(msg.sender, 1000000 * 10**4);
    }

    function decimals() public view virtual override returns (uint8) {
        return 4;
    }
}