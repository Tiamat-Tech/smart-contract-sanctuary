// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyNFT is ERC20 {
    constructor() ERC20("TAREK", "TR2") {
        _mint(msg.sender, 1000000000000000000000000000000000000 * 10^18);
    }
}