// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FARM is ERC20 {
    constructor() public ERC20("FARM Reward Token", "FARM") {
        _mint(msg.sender, 550000000000000000000000);
    }
}