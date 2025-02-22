// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PandaToken is ERC20 {
    constructor() ERC20("Panda Token", "PT") {
        _mint(msg.sender, 1000000000000 * 10 ** decimals());
    }
}