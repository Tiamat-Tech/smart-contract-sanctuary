// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VRK is ERC20 {
    constructor() ERC20("VRK", "VRK") {
        _mint(msg.sender, 1000000 * 10**uint256(decimals()));
    }
}