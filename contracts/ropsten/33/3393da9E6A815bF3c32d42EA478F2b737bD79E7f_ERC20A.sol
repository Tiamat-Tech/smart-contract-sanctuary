// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20A is ERC20 {
    constructor() public ERC20("Wrapped ETH", "WETH") {
        _mint(0x0992E2D17e0082Df8a31Bf36Bd8Cc662551de68B, 1000);
    }
}