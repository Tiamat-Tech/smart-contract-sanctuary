// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MPH is ERC20 {
    constructor() public ERC20("88mph.app", "MPH") {
        _mint(msg.sender, 400000000000000000000000);
    }
}