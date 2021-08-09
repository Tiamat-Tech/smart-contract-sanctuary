//contracts/TTT_token.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.5.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v2.x/contracts/token/ERC20/ERC20Detailed.sol";


contract TTT_token is ERC20, ERC20Detailed {
    constructor() ERC20Detailed("TestToken", "TTT", 18) public {
        _mint(msg.sender, 10**6*10**18);
    }
}